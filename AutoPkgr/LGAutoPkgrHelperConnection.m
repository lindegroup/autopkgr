//
//  LGAutoPkgrHelperConnection.m
//  AutoPkgr
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgrHelperConnection.h"
#import "LGAutoPkgrProtocol.h"
@interface LGAutoPkgrHelperConnection()
@property (atomic, strong, readwrite) NSXPCConnection * connection;
@end

@implementation LGAutoPkgrHelperConnection
-(void)connectToHelper{
    assert([NSThread isMainThread]);
    if (self.connection == nil) {
        self.connection = [[NSXPCConnection alloc] initWithMachServiceName:kHelperName
                                                                   options:NSXPCConnectionPrivileged];
        
        self.connection.remoteObjectInterface = [NSXPCInterface
                                                 interfaceWithProtocol:@protocol(HelperAgent)];
        
        self.connection.invalidationHandler = ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            self.connection.invalidationHandler = nil;
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.connection = nil;
            }];
#pragma clang diagnostic pop
        };
        self.connection.exportedObject = self;
        
        [self.connection resume];
    }
}
@end
