//
//  LGAutoPkgrHelper.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 7/28/14.
//  Copyright 2014-2015 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgrHelper.h"
#import "LGAutoPkgrProtocol.h"
#import "LGEncryptedKeychainHelper.h"

#import "LGError.h"
#import "LGPackageRemover.h"
#import "LGProgressDelegate.h"
#import "LGSharedConts.h"

#import "SNTCodesignChecker.h"

#import <AHLaunchCtl/AHLaunchCtl.h>
#import <AHLaunchCtl/AHServiceManagement.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <pwd.h>
#import <syslog.h>

#import "NSData+taskData.h"
#import "NSString+split.h"

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

// Parent directory for all of the keyFiles. Each AutoPkgr user has a unique file.
static NSString *const kLGEncryptedKeysParentDirectory = @"/var/db/.AutoPkgrKeys";

static dispatch_queue_t autopkgr_kc_access_synchronizer_queue()
{
    static dispatch_queue_t dispatch_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue = dispatch_queue_create("com.lindegroup.autopkgr.helper.kcaccess.queue", DISPATCH_QUEUE_SERIAL);
    });

    return dispatch_queue;
}

@interface LGAutoPkgrHelper () <AutoPkgrHelperAgent, NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (readonly) NSXPCConnection *connection;
@property (weak) NSXPCConnection *relayConnection;

@property (strong, nonatomic) NSMutableArray *connections;
@property (nonatomic, assign) BOOL helperToolShouldQuit;
@end

@implementation LGAutoPkgrHelper {
    void (^_resign)(BOOL);

@private
    NSString *_keyChainKey;
}

- (id)init
{
    self = [super init];
    if (self) {
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kLGAutoPkgrHelperToolName];
        self->_listener.delegate = self;
        self->_connections = [NSMutableArray new];
    }
    return self;
}

- (void)run
{
    [self.listener resume];
    while (!self.helperToolShouldQuit) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }

    syslog(LOG_INFO, "Quitting AutoPkgr helper application.");
}

#pragma mark - NSXPCListenerDelegate
//----------------------------------------
// Set up the one method of NSXPCListener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    BOOL valid = [self newConnectionIsValid:newConnection];

    if (valid) {
        NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(AutoPkgrHelperAgent)];
        newConnection.exportedInterface = exportedInterface;
        newConnection.exportedObject = self;

        // We have one method that can handle multiple input types
        NSSet *acceptedClasses = [NSSet setWithObjects:[AHLaunchJobSchedule class],
                                                       [NSNumber class], nil];

        [newConnection.exportedInterface setClasses:acceptedClasses
                                        forSelector:@selector(scheduleRun:user:program:authorization:reply:)
                                      argumentIndex:0
                                            ofReply:NO];

        __weak typeof(newConnection) weakConnection = newConnection;
        // If all connections are invalidated on the remote side, shutdown the helper.
        newConnection.invalidationHandler = ^() {
            if ([weakConnection isEqualTo:self.relayConnection] && _resign) {
                _resign(YES);
            }

            [self.connections removeObject:weakConnection];

            if (self.connections.count == 0) {
                [self quitHelper:^(BOOL success){
                }];
            }
        };

        [self.connections addObject:newConnection];
        [newConnection resume];

        syslog(LOG_INFO, "Connection Success...");
        return YES;
    }

    syslog(LOG_ERR, "Error creating xpc connection...");
    return NO;
}

- (NSXPCConnection *)connection
{
    return [self.connections lastObject];
}

#pragma mark - Password
- (void)getKeychainKey:(void (^)(NSString *, NSError *))reply
{
    NSXPCConnection *connection = self.connection;

    dispatch_sync(autopkgr_kc_access_synchronizer_queue(), ^{
        // 10.8 has displayed instability on some systems when accessing the system keychain in
        // rapid succession. So reluctantly we need to bypass direct calls to the Security framework
        // in this method, and simply store the keyChain data in memory  for the life of the helper.
        // @note the getKeychain: call is still protected by codesign checking done when accepting new connecions so has "almost" the same level of security.
        if (floor(NSFoundationVersionNumber) < NSFoundationVersionNumber10_9) {
            if (_keyChainKey) {
                syslog(LOG_ALERT, "[ 10.8 ] Helper Found keychain key in memory.");
                return reply(_keyChainKey, nil);
            }
        }
#if DEBUG
        syslog(LOG_ALERT, "Connection querying keychain %s : EUID: %d", connection.description.UTF8String, connection.effectiveUserIdentifier);
#endif

        // Effective user id used to determine location of the user's AutoPkgr keychain.
        uid_t euid = connection.effectiveUserIdentifier;
        if (euid == 0) {
            [connection invalidate];
            return;
        }


        NSError *error = nil;
        NSString *password = [LGEncryptedKeychainHelper getKeychainPassword:connection
                                                                      error:&error];

        if (floor(NSFoundationVersionNumber) < NSFoundationVersionNumber10_9) {
            if (password) {
                _keyChainKey = password;
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            syslog(LOG_ALERT, "Sending keychain key to AutoPkgr.");
            reply(password, error);
        });
    });
}

#pragma mark - AutoPkgr Schedule
- (void)scheduleRun:(AHLaunchJobSchedule *)scheduleOrInterval
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply
{
    // Display Authorization Prompt based on external form contained in authData.
    // If user cancels the challenge, or any other problem occurs it will return a populated error object, with the details

    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];

    // If authorization was successful continue,
    if (error == nil) {
        if ([self launchPathIsValid:program error:&error] &&
            [self userIsValid:user
                        error:&error]) {

            AHLaunchJob *job = [AHLaunchJob new];
            job.Program = program;
            job.Label = kLGAutoPkgrLaunchDaemonPlist;
            job.ProgramArguments = @[ program, @"-runInBackground", @"YES" ];

            if ([scheduleOrInterval isKindOfClass:[AHLaunchJobSchedule class]]) {
                job.StartCalendarInterval = scheduleOrInterval;
            }
            else if ([scheduleOrInterval isKindOfClass:[NSNumber class]]) {
                job.StartInterval = [(NSNumber *)scheduleOrInterval integerValue];
            }

            job.SessionCreate = YES;
            job.UserName = user;

            /* Setting __CFPREFERENCES_AVOID_DAEMON helps preferences sync
             * between the background run managed by launchd and the main
             * app running in an Aqua session. */
            job.EnvironmentVariables = @{ @"__CFPREFERENCES_AVOID_DAEMON" : @"1" };

            if (jobIsRunning(job.Label, kAHGlobalLaunchDaemon)) {
                syslog(LOG_ALERT, "Reloading current schedule.");
                [[AHLaunchCtl sharedController] unload:job.Label inDomain:kAHGlobalLaunchDaemon error:nil];
            }

            [[AHLaunchCtl sharedController] add:job toDomain:kAHGlobalLaunchDaemon error:&error];
        }
    }

    reply(error);
}

- (void)removeScheduleWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error = nil;
    if (!error) {
        [[AHLaunchCtl sharedController] remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];
    }

    reply(error);
}

#pragma mark - Installer
- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;
{
    NSError *error = nil;
    NSXPCConnection *connection = self.connection;

    if ((error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd])) {
        return reply(error);
    }

    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];
    [connection.remoteObjectProxy bringAutoPkgrToFront];

    __block double progress = 75.00;

    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/sbin/installer";
    task.arguments = @[ @"-verbose", @"-pkg", path, @"-target", @"/" ];

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;

    [[pipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
        NSData *data = fh.availableData;
        if (data.length) {
            progress++;
            NSString *message = data.taskData_splitLines.firstObject;
            if (message.length && ![message isEqualToString:@"#"]) {
                message = [message stringByReplacingOccurrencesOfString:@"installer: " withString:@""];

                [connection.remoteObjectProxy updateProgress:message
                                                    progress:progress];
            }
        }
    }];

    [task setTerminationHandler:^(NSTask *endTask) {
        NSError *error = [LGError errorFromTask:endTask];
        reply(error);
    }];

    [task launch];
}

- (void)uninstallPackagesWithIdentifiers:(NSArray *)identifiers authorization:(NSData *)authData reply:(uninstallPackageReplyBlock)reply
{

    NSError *error;
    if ((error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd])) {
        return reply(nil, nil, error);
    }

    LGPackageRemover *remover = [[LGPackageRemover alloc] init];
    remover.dryRun = NO;

    [remover removePackagesWithIdentifiers:identifiers
                                  progress:^(NSString *message, double progress) {
#if DEBUG
                                      syslog(LOG_INFO, "[UNINSTALLER]: %s", message.UTF8String);
#endif
                                      // TODO: send progress updates
                                  }
                                     reply:reply];
}

#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply
{
    // This will cause the run-loop to exit. You should call it
    // from the main app during applicationShouldTerminate:.
    if (_resign) {
        _resign(YES);
    }

    for (NSXPCConnection *connection in self.connections) {
        [connection invalidate];
    }
    [self.connections removeAllObjects];

    self.helperToolShouldQuit = YES;
    reply(!self.connection);
}

- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;
{
    NSError *error;
    if (jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon)) {
        [[AHLaunchCtl sharedController] remove:kLGAutoPkgrLaunchDaemonPlist
                                    fromDomain:kAHGlobalLaunchDaemon
                                         error:&error];
    }

    reply(error);
}

- (void)uninstall:(NSData *)authData removeKeychains:(BOOL)removeKeychains packages:(NSArray *)packageIDs reply:(void (^)(NSError *))reply
{
    NSError *error;

    /*////////////////////////////////////////////////////////////////////
    //   Remove LaunchD schedule                                        //
    ////////////////////////////////////////////////////////////////////*/
    if (jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon)) {
        [[AHLaunchCtl sharedController] remove:kLGAutoPkgrLaunchDaemonPlist
                                    fromDomain:kAHGlobalLaunchDaemon
                                         error:&error];
    }

    /*////////////////////////////////////////////////////////////////////
    //   Remove Keychain items                                          //
    ////////////////////////////////////////////////////////////////////*/
    if (removeKeychains) {
        [LGEncryptedKeychainHelper purge:self.connection
                                   error:&error];
    }

    //////////////////////////////////////////////////////////////////////
    //   Remove Integrations                                            //
    //////////////////////////////////////////////////////////////////////

    // TODO: remove selected packages...
    reply(error);
}

#pragma mark - IPC communication from background run
- (void)registerMainApplication:(void (^)(BOOL resign))resign;
{
    NSXPCConnection *connection = self.connection;
    if (connection && !self.relayConnection) {
        self.relayConnection = connection;
        self.relayConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];
        _resign = resign;
    }
    else {
        resign(YES);
    }
}

- (void)sendMessageToMainApplication:(NSString *)message progress:(double)progress error:(NSError *)error state:(LGBackgroundTaskProgressState)state;
{
    if (self.relayConnection) {
        switch (state) {
        case kLGAutoPkgProgressStart:
            [self.relayConnection.remoteObjectProxy startProgressWithMessage:message];
            break;
        case kLGAutoPkgProgressProcessing:
            [self.relayConnection.remoteObjectProxy updateProgress:message progress:progress];
            break;
        case kLGAutoPkgProgressComplete:
            [self.relayConnection.remoteObjectProxy stopProgress:error];
            break;
        default:
            break;
        }
    }
}

- (BOOL)launchPathIsValid:(NSString *)path error:(NSError *__autoreleasing *)error;
{
    // Get the executable path of the helper tool (self).  Then compare that to the
    // binary (path) the helper tool is asked to set as the launchd.plist "Program" key.

    SNTCodesignChecker *selfCS = [[SNTCodesignChecker alloc] initWithSelf];
    SNTCodesignChecker *remoteCS = [[SNTCodesignChecker alloc] initWithBinaryPath:path];

    BOOL launchPathIsValid = [selfCS signingInformationMatches:remoteCS];
    if (!launchPathIsValid) {
        if (error) {
            NSString *suggestionFormat = NSLocalizedString(@"The code signature of the AutoPkgr executable was not valid or did not match the registry. The offending application's code signing credentials are %@ for the binary located at %@.", nil);

            NSString *recoverySuggestion = [NSString stringWithFormat:suggestionFormat, remoteCS.description, path];

            NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : @"Invalid binary for a scheduled run.",
                                         NSLocalizedRecoverySuggestionErrorKey : recoverySuggestion };
            *error = [NSError errorWithDomain:kLGApplicationName code:1 userInfo:errorDict];
        }
    }

    return launchPathIsValid;
}

- (BOOL)userIsValid:(NSString *)user error:(NSError *__autoreleasing *)error;
{
    // As of 1.3.1 we're no longer using SCDynamicStoreCopyConsoleUser()
    // This is due to situations where RDPd users were unable to setup schedule
    // since the console user was virtual and the function returned `loginwindow`
    // Now we'll use the euid of the NSXPCConnection to check the proposed user.

    struct passwd *pw = getpwuid(self.connection.effectiveUserIdentifier);
    NSString *effectiveUserName = [NSString stringWithUTF8String:pw->pw_name];
    NSString *ghPrefs = [NSString stringWithFormat:@"%s/Library/Preferences/com.github.autopkg.plist", pw->pw_dir];

    if ([user isEqualToString:effectiveUserName] && access(ghPrefs.UTF8String, F_OK) == 0) {
        return YES;
    }
    else {
        if (error) {
            NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : @"Invalid user for scheduling autopkg run",
                                         NSLocalizedRecoverySuggestionErrorKey : @"There was a problem either verifying the user or with the user's configuration. The user must be have a home directory set, and valid com.github.autopkg preferences." };
            *error = [NSError errorWithDomain:kLGApplicationName code:1 userInfo:errorDict];
        }
        return NO;
    }
}

- (BOOL)newConnectionIsValid:(NSXPCConnection *)newConnection
{
    BOOL success = NO;
    pid_t pid = newConnection.processIdentifier;

    SNTCodesignChecker *selfCS = [[SNTCodesignChecker alloc] initWithSelf];
    SNTCodesignChecker *remoteCS = [[SNTCodesignChecker alloc] initWithPID:pid];

    if (!(success = [remoteCS signingInformationMatches:selfCS])) {
        // If there is an problem log the error.
        syslog(LOG_ALERT, "[ERROR] The codesigning signature of one of the following items could not be verified. If either of the following messages displays NULL, please quit AutoPkgr, and manually remove the helper tool binary at %s.", selfCS.binaryPath.UTF8String);
        syslog(LOG_ALERT, "[ERROR] AutoPkgr codesign stats: %s", remoteCS.description.UTF8String);
        syslog(LOG_ALERT, "[ERROR] Helper Tool codesign stats: %s", selfCS.description.UTF8String);
    }
    else {
#if DEBUG
        syslog(LOG_ALERT, "[DEBUG] AutoPkgr codesign stats: %s", remoteCS.description.UTF8String);
        syslog(LOG_ALERT, "[DEBUG] Helper Tool codesign stats: %s", selfCS.description.UTF8String);
#endif
    }
    return success;
}

@end
