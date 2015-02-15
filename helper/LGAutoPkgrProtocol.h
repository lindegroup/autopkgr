//
//  LGAutoPkgrProtocol.h
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

#import <Foundation/Foundation.h>
#import "LGConstants.h"
#import "LGAutoPkgrAuthorizer.h"

@protocol HelperAgent <NSObject>

# pragma mark - Password
- (void)getPasswordForAccount:(NSString *)account reply:(void (^)(NSString *password, NSError *error))reply;

- (void)savePassword:(NSString *)password forAccount:(NSString *)account reply:(void (^)(NSError *error))reply;

#pragma mark - Schedule
#pragma mark-- Add
- (void)scheduleRun:(NSInteger)interval
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply;


#pragma mark -- Remove
- (void)removeScheduleWithAuthorization:(NSData *)authData
                                  reply:(void (^)(NSError *error))reply;

#pragma mark - Install Package
- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;

#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply;
- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;

@end
