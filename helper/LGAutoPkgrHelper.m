//
//  LGAutoPkgrHelper.m
//  AutoPkgr - Privileged Helper Tool
//
//  Created by Eldon Ahrold on 7/28/14.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgrHelper.h"
#import "LGAutoPkgrProtocol.h"
#import "LGAutoPkgr.h"
#import "LGProgressDelegate.h"

#import "AHKeychain.h"
#import "SNTCodesignChecker.h"
#import <AHLaunchCtl/AHLaunchCtl.h>

#import <pwd.h>
#import <syslog.h>
#import <SystemConfiguration/SystemConfiguration.h>

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

@interface LGAutoPkgrHelper () <HelperAgent, NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (weak) NSXPCConnection *connection;
@property (strong, nonatomic) NSMutableSet *connections;
@property (nonatomic, assign) BOOL helperToolShouldQuit;
@end

@implementation LGAutoPkgrHelper

- (id)init
{
    self = [super init];
    if (self) {
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kLGAutoPkgrHelperToolName];
        self->_listener.delegate = self;
    }
    return self;
}

- (void)run
{
    [self.listener resume];
    while (!self.helperToolShouldQuit) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
    syslog(LOG_ALERT, "Quiting AutoPkgr helper application.");
}

#pragma mark - NSXPCListenerDelegate
//----------------------------------------
// Set up the one method of NSXPCListener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{

    if ([self newConnectionIsValid:newConnection]) {
        NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperAgent)];
        newConnection.exportedInterface = exportedInterface;

        newConnection.exportedObject = self;
        self.connection = newConnection;

        __weak typeof(newConnection) weakConnection = newConnection;
        // If all connections are invalidated on the remote side,
        // shutdown the helper.
        newConnection.invalidationHandler = ^() {
            __strong typeof(newConnection) strongConnection = weakConnection;
            [self.connections removeObject:strongConnection];
            if (!self.connections.count) {
                [self quitHelper:^(BOOL success) {}];
            }
        };

        [newConnection resume];
        [self.connections addObject:newConnection];
        syslog(LOG_INFO, "Connection Success...");
        return YES;
    }

    syslog(LOG_ERR, "Error creating xpc connection...");
    return NO;
}

#pragma mark - Password
- (void)getPasswordForAccount:(NSString *)account reply:(void (^)(NSString *, NSError *))reply
{
    NSError *error;

    uid_t uid;
    NSString *loggedInUser = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, &uid, NULL));

    // If a user is logged in check that the connection has the same
    // effective user. This should prevent some potential exploit
    // If it's running at the login window we can't do the same check
    if (loggedInUser && (uid != self.connection.effectiveUserIdentifier)) {
        [self.connection invalidate];
        return;
    }

    AHKeychainItem *item = [self setupKeychainItemForAccount:account];
    [[AHKeychain systemKeychain] getItem:item error:&error];

    reply(item.password, error);
}

- (void)savePassword:(NSString *)password forAccount:(NSString *)account reply:(void (^)(NSError *))reply
{
    NSError *error;
    if ((account && account.length) && (password && password.length)) {
        AHKeychainItem *item = [self setupKeychainItemForAccount:account];
        item.password = password;

        [[AHKeychain systemKeychain] saveItem:item error:&error];
    } else {
        error = [NSError errorWithDomain:kLGApplicationName code:12
                                userInfo:@{ NSLocalizedDescriptionKey : @"Could not save password, either username or password is blank" }];
    }
    reply(error);
}

#pragma mark - AutoPkgr Schedule
- (void)scheduleRun:(NSInteger)timer
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply
{

    // Display Authorization Prompt based on external form contained in
    // authData. If user cancels the challenge, or any other problem occurs
    // it will return a populated error object, with the details
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];

    // If authorization was successful continue,
    if (!error) {
        // Check if the launch path and user are valid, and that the timer has a sensible mininum.
        if ([self launchPathIsValid:program error:&error] &&
            [self userIsValid:user error:&error] && timer >= 3600) {
            AHLaunchJob *job = [AHLaunchJob new];
            job.Program = program;
            job.Label = kLGAutoPkgrLaunchDaemonPlist;
            job.ProgramArguments = @[ program, @"-runInBackground", @"YES" ];
            job.StartInterval = timer;
            job.SessionCreate = YES;
            job.UserName = user;

            [[AHLaunchCtl sharedController] add:job toDomain:kAHGlobalLaunchDaemon error:&error];
        }
    }

    reply(error);
}

- (void)removeScheduleWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
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
    NSError *error;
    error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd];
    if (error != nil) {
        if (error.code == errAuthorizationCanceled) {
            reply(nil);
        } else {
            reply(error);
        }
        return;
    }

    self.connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];

    [self.connection.remoteObjectProxy bringAutoPkgrToFront];

    __block double progress = 75.00;

    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/sbin/installer";
    task.arguments = @[ @"-verbose", @"-pkg", path, @"-target", @"/" ];

    task.standardError = [NSPipe pipe];
    task.standardOutput = [NSPipe pipe];

    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
        if (fh.availableData) {
            progress ++;
            NSString *rawMessage = [[NSString alloc] initWithData:fh.availableData encoding:NSUTF8StringEncoding];
            NSArray *allMessages = [ rawMessage componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

            for (NSString *message in allMessages) {
                if (message.length && ![message isEqualToString:@"#"]) {
                    [self.connection.remoteObjectProxy updateProgress:message
                                                             progress:progress];
                }
            }
        }
    }];

    [task setTerminationHandler:^(NSTask *endTask) {
        NSError *error = [LGError errorWithTaskError:endTask verb:kLGAutoPkgUndefinedVerb];
        reply(error);
    }];

    [task launch];
}

#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply
{
    // this will cause the run-loop to exit;
    // you should call it via NSXPCConnection
    // during the applicationShouldTerminate routine
    for (NSXPCConnection *connection in self.connections) {
        [connection invalidate];
    }
    [self.connections removeAllObjects];

    self.helperToolShouldQuit = YES;
    reply(YES);
}

- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;
{
    NSError *error;
    error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd];

    if (error) {
        return reply(error);
    }

    if (jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon)) {
        [[AHLaunchCtl sharedController] remove:kLGAutoPkgrLaunchDaemonPlist
                                    fromDomain:kAHGlobalLaunchDaemon
                                         error:nil];
    }

    [AHLaunchCtl removeFilesForHelperWithLabel:kLGAutoPkgrHelperToolName error:&error];
    reply(error);

    [AHLaunchCtl uninstallHelper:kLGAutoPkgrHelperToolName prompt:@"" error:nil];
}

#pragma mark - Private
- (BOOL)launchPathIsValid:(NSString *)path error:(NSError *__autoreleasing *)error;
{
    // Get the executable path of the helper tool.  We use this to compare against
    // the program the helper tool is asked add as the launchd.plist "Program" key

    SNTCodesignChecker *selfCS = [[SNTCodesignChecker alloc] initWithSelf];
    SNTCodesignChecker *remoteCS = [[SNTCodesignChecker alloc] initWithBinaryPath:path];

    return [selfCS signingInformationMatches:remoteCS];
}

- (BOOL)userIsValid:(NSString *)user error:(NSError *__autoreleasing *)error;
{
    // TODO: decide what criteria qualifies a valid user.
    // In future release we could potentially specify a user other
    // than the current logged in user to run the schedule as, but
    // we would need to check a number of criteria. For now just check
    // that the user matches the logged in (console) user.
    BOOL success = YES;
    NSString *loggedInUser = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL));
    syslog(LOG_INFO, "Checking that logged in user is the same as the user to run the schedule as: %s", loggedInUser.UTF8String);

    if (!loggedInUser || !user || ![user isEqualToString:loggedInUser]) {
        if (error) {
            NSDictionary *errorDict = @{ NSLocalizedDescriptionKey : @"Invalid user for scheduling autopkg run",
                                         NSLocalizedRecoverySuggestionErrorKey : @"There was a problem either verifying the user, or with the user's configuration. The user must be have a home directory set, a shell environment, and valid com.github.autopkg preferences." };
            *error = [NSError errorWithDomain:kLGApplicationName code:1 userInfo:errorDict];
        }
        success = NO;
    }

    return success;
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
    } else {
#if DEBUG
        syslog(LOG_ALERT, "[DEBUG] AutoPkgr codesign stats: %s", remoteCS.description.UTF8String);
        syslog(LOG_ALERT, "[DEBUG] Helper Tool codesign stats: %s", selfCS.description.UTF8String);
#endif
    }

    return success;
}

- (AHKeychainItem *)setupKeychainItemForAccount:(NSString *)account
{
    AHKeychainItem *item = [[AHKeychainItem alloc] init];
    item.account = account;
    item.label = [kLGApplicationName stringByAppendingString:@" Email Password"];

    // Append the EUID to the service string to limit access
    // to only items created by the same user.
    item.service = [item.label stringByAppendingFormat:@" UID: %d", self.connection.effectiveUserIdentifier];
    return item;
}
@end
