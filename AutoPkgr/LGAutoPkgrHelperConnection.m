//
//  LGAutoPkgrHelperConnection.m
//  AutoPkgr
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

#import "LGAutoPkgrHelperConnection.h"
#import "LGAutoPkgrProtocol.h"
@interface LGAutoPkgrHelperConnection ()
@property (atomic, strong, readwrite) NSXPCConnection *connection;
@end

@implementation LGAutoPkgrHelperConnection
- (void)connectToHelper
{
    assert([NSThread isMainThread]);
    if (self.connection == nil) {
        self.connection = [[NSXPCConnection alloc] initWithMachServiceName:kLGAutoPkgrHelperToolName
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
