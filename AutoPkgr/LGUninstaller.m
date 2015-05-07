// LGUninstaller.m
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGUninstaller.h"
#import "LGLogger.h"
#import "LGAutoPkgrHelperConnection.h"

@implementation LGUninstaller

- (void)uninstallPackagesWithIdentifiers:(NSArray *)packageIdentifiers
                                   reply:(void (^)(NSError *error))reply
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
        assert(authorization != nil);

        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];

        helper.connection.exportedObject = _progressDelegate;
        helper.connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];

        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            DLog(@"%@",error);
            reply(error);
        }] uninstallPackagesWithIdentifiers:packageIdentifiers authorization:authorization reply:^(NSArray *removed, NSArray *remain, NSError *error) {
            if (removed.count) {
                DLog(@"Successfully removed \t%@", [removed componentsJoinedByString:@"\n\t"]);
            }
            if (remain.count) {
                DLog(@"Failed to removed \t%@", [remain componentsJoinedByString:@"\n\t"]);
            }
            
            reply(error);
        }];
    }];
}

- (void)removeFilesAtPaths:(NSArray *)fileList
                     reply:(void (^)(NSError *error))reply
{
    reply(nil);
}

- (void)removePriviledgedFilesAtPaths:(NSArray *)fileList
                                reply:(void (^)(NSError *error))reply
{
    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);

    reply(nil);
}

@end
