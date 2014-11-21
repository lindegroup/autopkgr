//
//  LGAutoPkgrHelper.m
//  AutoPkgr - Priviledged Helper Tool
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
#import <AHLaunchCtl/AHLaunchCtl.h>
#import "AHCodesignVerifier.h"
#import "AHKeychain.h"

#import <pwd.h>
#import <syslog.h>

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

@interface LGAutoPkgrHelper () <HelperAgent, NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (weak) NSXPCConnection *connection;
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
}

#pragma mark - AutoPkgr Schedule
- (void)scheduleRun:(NSInteger)timer
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply
{

    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];

    if (!error) {
        if ([self launchPathIsValid:program error:&error] && [self userIsValid:user error:&error]) {
            AHLaunchJob *job = [AHLaunchJob new];
            job.Program = program;
            job.Label = kLGAutoPkgrLaunchDaemonPlist;
            job.ProgramArguments = @[ program, @"-runInBackground", @"YES" ];
            job.StartInterval = timer;
            job.SessionCreate = YES;
            job.UserName = user;

            [[AHLaunchCtl sharedControler] add:job toDomain:kAHGlobalLaunchDaemon error:&error];
        }
    }

    reply(error);
}

- (void)removeScheduleWithAuthorization:(NSData *)authData reply:(void (^)(NSError *))reply
{
    NSError *error = [LGAutoPkgrAuthorizer checkAuthorization:authData
                                                      command:_cmd];
    if (!error) {
        [[AHLaunchCtl sharedControler] remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];
    }

    reply(error);
}

- (BOOL)launchPathIsValid:(NSString *)path error:(NSError *__autoreleasing *)error;
{
    NSString *helperExecPath = [[[NSProcessInfo processInfo] arguments] firstObject];
    return [AHCodesignVerifier codesignOfItemAtPath:path
                                 isSameAsItemAtPath:helperExecPath
                                              error:error];
}

- (BOOL)userIsValid:(NSString *)user error:(NSError *__autoreleasing *)error;
{
    // TODO: decide what criteria qualifies a valid user.
    // In future release we could potentially specify a user other
    // than the current logged in user to run the shcedule as, but
    // we would need to check a number of criteria
    return YES;
}


#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply
{
    // this will cause the run-loop to exit;
    // you should call it via NSXPCConnection
    // during the applicationShouldTerminate routine
    self.helperToolShouldQuit = YES;
    reply(YES);
}

- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;
{
    NSError *error;

    error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd];
    if (error != nil) {
        reply(error);
        return;
    }

    NSTask *task = [NSTask new];
    task.launchPath = @"/usr/sbin/installer";
    task.arguments = @[ @"-pkg", path, @"-target", @"/" ];
    task.standardError = [NSPipe pipe];

    [task launch];
    [task waitUntilExit];

    error = [LGError errorWithTaskError:task verb:kLGAutoPkgUndefinedVerb];

    reply(error);
}

- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;
{
    NSError *error;
    error = [LGAutoPkgrAuthorizer checkAuthorization:authData command:_cmd];

    if (error) {
        return reply(error);
    }

    if (jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon)) {
        [[AHLaunchCtl sharedControler] remove:kLGAutoPkgrLaunchDaemonPlist
                                   fromDomain:kAHGlobalLaunchDaemon
                                        error:nil];
    }

    [AHLaunchCtl removeFilesForHelperWithLabel:kLGAutoPkgrHelperToolName error:&error];
    reply(error);
    [AHLaunchCtl uninstallHelper:kLGAutoPkgrHelperToolName prompt:@"" error:nil];
}

//----------------------------------------
// Set up the one method of NSXPClistener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{

    newConnection.exportedObject = self;
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperAgent)];

    self.connection = newConnection;
    [self.connection auditSessionIdentifier];

    [newConnection resume];
    return YES;
}
@end
