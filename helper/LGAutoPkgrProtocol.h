//
//  LGAutoPkgrProtocol.h
//  AutoPkgr - Priviledged Helper Integration
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
@class AHLaunchJobSchedule;

typedef NS_ENUM(NSInteger, LGBackgroundTaskProgressState) {
    kLGAutoPkgProgressStart = -1,
    kLGAutoPkgProgressProcessing = 0,
    kLGAutoPkgProgressComplete = 1
};

typedef void (^uninstallPackageReplyBlock)(NSArray *removed, NSArray *remain, NSError *error);

@protocol HelperAgent <NSObject>

# pragma mark - Password / KeyFile
- (void)getKeychainKey:(void (^)(NSString *key, NSError *error))reply;

#pragma mark - Schedule
#pragma mark-- Add
- (void)scheduleRun:(AHLaunchJobSchedule *)scheduleOrInterval
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

- (void)uninstallPackagesWithIdentifiers:(NSArray *)identifiers
                           authorization:(NSData *)authData
                                   reply:(uninstallPackageReplyBlock)reply;

#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply;
- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;

#pragma mark - IPC messaging
- (void)registerMainApplication:(void (^)(BOOL resign))resign;

- (void)sendMessageToMainApplication:(NSString *)message
                            progress:(double)progress
                               error:(NSError *)error
                            state:(LGBackgroundTaskProgressState)state;

@end
