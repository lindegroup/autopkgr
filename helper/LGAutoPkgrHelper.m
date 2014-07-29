//
//  LGAutoPkgrHelper.m
//  AutoPkgr
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgrHelper.h"
#import "LGAutoPkgrProtocol.h"
#import "LGConstants.h"
#import "AHLaunchCtl.h"

static const NSTimeInterval kHelperCheckInterval = 1.0; // how often to check whether to quit

@interface LGAutoPkgrHelper()<HelperAgent,NSXPCListenerDelegate>
@property (atomic, strong, readwrite) NSXPCListener   *listener;
@property (weak) NSXPCConnection *connection;
@property (nonatomic, assign) BOOL helperToolShouldQuit;
@end

@implementation LGAutoPkgrHelper

-(id)init
{
    self = [super init];
    if(self){
        self->_listener = [[NSXPCListener alloc] initWithMachServiceName:kHelperName];
        self->_listener.delegate = self;
    }
    return self;
}

-(void)run
{
    [self.listener resume];
    while (!self.helperToolShouldQuit)
    {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:kHelperCheckInterval]];
    }
}

-(void)scheduleRun:(NSInteger)interval
              user:(NSString *)user
           program:(NSString*)program
         withReply:(void (^)(NSError *))reply
{
    NSError *error;
    AHLaunchJob *job = [AHLaunchJob new];
    job.Program = program;
    job.Label = kLGAutoPkgrLaunchDaemonPlist;
    job.ProgramArguments = @[program,@"-runInBackground",@"YES"];
    job.StartInterval = interval;
    job.UserName = user;
    
    [[AHLaunchCtl sharedControler]add:job toDomain:kAHGlobalLaunchDaemon error:&error];
    
    reply(error);
}

-(void)removeScheduleWithReply:(void (^)(NSError *))reply
{
    NSError *error;
    [[AHLaunchCtl sharedControler]remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];
    reply(error);
}
-(void)quitHelper:(void (^)(BOOL success))reply{
    // this will cause the run-loop to exit;
    // you should call it via NSXPCConnection
    // during the applicationShouldTerminate routine
    self.helperToolShouldQuit = YES;
    reply(YES);
}

-(void)uninstall:(void (^)(NSError *))reply{
    reply(nil);
//    [AHLaunchCtl uninstallHelper:kHelperName error:nil];
}


//----------------------------------------
// Set up the one method of NSXPClistener
//----------------------------------------
- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    
    newConnection.exportedObject = self;
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(HelperAgent)];
    self.connection = newConnection;
    
    [newConnection resume];
    return YES;
}
@end
