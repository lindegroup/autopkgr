// LGUserNotifications.m
//
// Copyright 2014 The Linde Group, Inc.
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

#import "LGUserNotifications.h"
#import "LGAutoPkgr.h"

@implementation LGUserNotifications{
    NSError *_currentError;
}

+ (void)sendNotificationOfTestEmailSuccess:(BOOL)success error:(NSError *)error
{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Email test completed.";

    notification.informativeText = success ? @"Successfully sent test email. Check your inbox to confirm" : @"There was a problem sending test email. Check your settings.";

    if (success) {
        [notification setHasActionButton:NO];
        [notification setHasReplyButton:NO];
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    } else {
        // Currently there's a modal window displayed for errors, in th future we could
        // present the error here instead
        if (error) {
            [notification setUserInfo:error.userInfo];
            [notification setActionButtonTitle:@"Show Error"];
            [notification setOtherButtonTitle:@"Dismiss"];
            [notification setHasActionButton:YES];
        }
    }
}

#pragma mark - NSUserNotificationDelegate
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    if (notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
        if ([notification.actionButtonTitle isEqualToString:@"Show Error"]) {
            [NSApp presentError:[NSError errorWithDomain:kLGApplicationName code:-1 userInfo:notification.userInfo]];
        }
    }
    
    [center removeDeliveredNotification:notification];
}

@end
