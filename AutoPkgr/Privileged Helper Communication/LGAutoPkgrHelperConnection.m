//
//  LGAutoPkgrHelperConnection.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 7/28/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "LGAutoPkgrHelperConnection.h"
#import <AHLaunchCtl/AHLaunchJobSchedule.h>
#import "LGLogger.h"

@interface LGAutoPkgrHelperConnection ()
@property (atomic, strong, readwrite) NSXPCConnection *connection;
@property (copy, nonatomic) void (^proxyErrorHandler)(NSError *);

@end

@implementation LGAutoPkgrHelperConnection

- (void)dealloc {
    DevLog(@"Invalidating connection");
}

- (instancetype)init
{
    assert([NSThread isMainThread]);
    if ( self = [super init] ) {

        self.connection = [[NSXPCConnection alloc] initWithMachServiceName:kLGAutoPkgrHelperToolName
                                                           options:NSXPCConnectionPrivileged];

        self.connection.remoteObjectInterface = [NSXPCInterface
            interfaceWithProtocol:@protocol(AutoPkgrHelperAgent)];

        NSSet *acceptedClasses = [NSSet setWithObjects:[AHLaunchJobSchedule class], [NSNumber class], nil];

        [self.connection.remoteObjectInterface setClasses:acceptedClasses
                                              forSelector:@selector(scheduleRun:user:program:authorization:reply:)
                                            argumentIndex:0 ofReply:NO];

        self.connection.invalidationHandler = ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            self.connection.invalidationHandler = nil;
#pragma clang diagnostic pop
        };
        self.connection.exportedObject = self;

        [self.connection resume];
    }
    return self;
}

- (instancetype)initWithProgressDelegate:(id)delegate {
    if (self = [self init]){
        self.connection.exportedObject = delegate;
        self.connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];
    }
    return self;
}

- (id<AutoPkgrHelperAgent>)connectionError:(void (^)(NSError *))handler {
    self.proxyErrorHandler = handler;
    return self.remoteObjectProxy;
}

- (id<AutoPkgrHelperAgent>)remoteObjectProxy {
    return [self.connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        if (_proxyErrorHandler){
            _proxyErrorHandler(error);
        }
        if (error.code != 4097){
            DevLog(@"%@", error);
        }
    }];
}

- (void)closeConnection {
    [self.connection invalidate];
}

@end
