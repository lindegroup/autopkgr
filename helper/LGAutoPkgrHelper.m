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
#import "LGAutoPkgr.h"
#import "LGAutoPkgrProtocol.h"
#import "LGProgressDelegate.h"

#import "SNTCodesignChecker.h"

#import <AHLaunchCtl/AHLaunchCtl.h>
#import <AHKeychain/AHKeychain.h>
#import <RNCryptor/RNEncryptor.h>
#import <RNCryptor/RNDecryptor.h>

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
- (void)getKeychainKey:(void (^)(NSString *, NSError *))reply
{
    // The password for the user's keychain
    NSString *password = nil;

    // raw data representing the password for the user's keychain
    NSData *passwordData = nil;

    // keyFile encoded with AES256 using the encryption password
    NSString *keyFile = nil;

    // data representing the keyFile
    NSData *encryptedKeyFileData = nil;

    // Password to decrypt the keyFile stored in the System.keychain
    NSString *encryptionPassword = nil;

    // Path to the ~/Library/Keychain/AutoPkgr.keychain
    NSString *appKeychainPath = nil;

    // parent directory for the keyfile
    NSString *encryptionKeyParentDir = nil;

    // Error
    NSError *error = nil;

    // Effective user id used to determine location of the user's AutoPkgr keychain.
    uid_t euid = self.connection.effectiveUserIdentifier;
    struct passwd *pw = getpwuid(euid);
    NSAssert(euid != 0, @"The euid of the connection should never be 0!");

    // Attributes used to set permissions on the keyFile and it's parent directory.
    NSDictionary *const attributes = @{
        NSFilePosixPermissions : [NSNumber numberWithShort:0700],
        NSFileOwnerAccountID : @(0),
        NSFileGroupOwnerAccountID : @(0),
    };

    NSFileManager *manager = [NSFileManager defaultManager];

    keyFile = [NSString stringWithFormat:@"/var/db/.AutoPkgrKeys/UID_%d", euid];
    encryptionKeyParentDir = @"/var/db/.AutoPkgrKeys";

    /*///////////////////////////////////////////////////////////////
    //  Encryption password in the System.keychain                 //
    ///////////////////////////////////////////////////////////////*/

    AHKeychainItem *item = [[AHKeychainItem alloc] init];
    item.service = @"AutoPkgr Common Decryption";
    item.account = @"com.lindegroup.AutoPkgr.decryption.key";
    BOOL newEncryptionPassword = NO;

    if ([[AHKeychain systemKeychain] getItem:item error:&error]) {
        // We found the password
        encryptionPassword = item.password;
    } else if (error.code == errSecItemNotFound) {
        // reset the error so it doesn't inadvertantly pass
        // back the wrong value
        error = nil;

        // Generate a new pass
        encryptionPassword = [[NSProcessInfo processInfo] globallyUniqueString];
        item.password = encryptionPassword;

        if ([[AHKeychain systemKeychain] saveItem:item error:&error]) {
            // Success, a new common encryption was generated.
            newEncryptionPassword = YES;
        } else {
            // If we can't create the keychain exit out here.
            // There's nothing more to be done.
            goto helper_reply;
        }
    } else {
        // some other error occurred when trying to find the item ???
        goto helper_reply;
    }

    // Get info on the current user
    // We use this as a safety valve. If a user has removed
    // their AutoPkgr.keychain delete the keyFile and start fresh.
    appKeychainPath = [NSString stringWithFormat:@"%s/Library/Keychains/AutoPkgr.keychain", pw->pw_dir];

    // Check for an old version of the keychainKey.
    BOOL keyFileExists = [manager fileExistsAtPath:keyFile];

    // If the keychain item has been deleted, try to remove the keyFile and start fresh.
    BOOL check1 = ![manager fileExistsAtPath:appKeychainPath] && keyFileExists;

    // If a new encryption key was generated, but an old keyFile exists.
    BOOL check2 = keyFileExists && newEncryptionPassword;

    // If either condition is true, remove the old keyFile
    if (check1 || check2) {
        syslog(LOG_ALERT, "Removing unusable keyFile...");
        if (![manager removeItemAtPath:keyFile error:nil]) {
            syslog(LOG_ALERT, "There was a problem removing the encrypted key file");
        }
    }

    /*////////////////////////////////////////////////////////////////////
     //   Encrypted keyFile into a root protected space                  //
     ////////////////////////////////////////////////////////////////////*/

    if (![manager fileExistsAtPath:keyFile]) {
        // keyFile does not exist.

        BOOL isDir;
        BOOL directoryExists = [manager fileExistsAtPath:encryptionKeyParentDir isDirectory:&isDir];

        if (!directoryExists) {
            if (![manager createDirectoryAtPath:encryptionKeyParentDir withIntermediateDirectories:NO attributes:attributes error:&error]) {
                // If we can't create this directory something is wrong, goto.
                syslog(LOG_ALERT, "[ERROR] Could not create the parent directory for the encrypted key files.");
                goto helper_reply;
            }
        } else if (directoryExists && !isDir) {
            // The path exists but is not a directory get, escape!.
            syslog(LOG_ALERT, "[ERROR] The %s exists, but it is not a directory, needs repair.", encryptionKeyParentDir.UTF8String);
            goto helper_reply;
        }

        // Generate some random data to use as the password for the user's keychain.
        passwordData = [RNCryptor randomDataOfLength:48];

        // Encrypt the random data into AES256.
        encryptedKeyFileData = [RNEncryptor encryptData:passwordData
                                           withSettings:kRNCryptorAES256Settings
                                               password:encryptionPassword
                                                  error:&error];

        // Write the encrypted data to the keyFile.
        [encryptedKeyFileData writeToFile:keyFile atomically:YES];

    } else {
        // The keyFile is there.

        // Read in the encrypted data of the keyFile.
        encryptedKeyFileData = [NSData dataWithContentsOfFile:keyFile];

        // Decrypt the data.
        passwordData = [RNDecryptor decryptData:encryptedKeyFileData
                                   withSettings:kRNCryptorAES256Settings
                                       password:encryptionPassword
                                          error:&error];
    }

    // Re set the attributes of the file to root only access.
    if (![manager setAttributes:attributes ofItemAtPath:keyFile error:nil]) {
        syslog(LOG_ALERT, "[ERROR] A problem was encountered updating keyFile's permissions.");
    }

    if (passwordData) {
        // set the password as the NSObject data descripton.
        password = passwordData.description;
    }

helper_reply:

    reply(password, error);
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

@end
