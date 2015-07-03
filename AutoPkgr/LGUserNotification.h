//
//  LGUserNotifications.h
//  AutoPkgr
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGNotificationService.h"

@interface LGUserNotificationsDelegate : NSObject <NSUserNotificationCenterDelegate>
- (instancetype)initAsDefaultCenterDelegate;
@end

@interface LGUserNotification : LGNotificationService <LGNotificationServiceProtocol>
+ (void)sendNotificationOfTestEmailSuccess:(BOOL)success error:(NSError *)error;

@end
