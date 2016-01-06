//
//  LGUserNotification.m
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

#import "LGUserNotification.h"
#import "LGAutoPkgr.h"

@implementation LGUserNotification {
    NSError *_currentError;
}

+ (NSString *)serviceDescription
{
    return NSLocalizedString(@"User Notifications", @"User Notification service description");
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"NSUserNotificatonsEnabled"];
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)templateIsFile {
    return NO;
}

+ (NSString *)defaultTemplate {
    return @"Updates occurred.";
};

- (void)send:(void (^)(NSError *))complete
{
    [self sendMessage:self.report.reportSubject title:nil complete:complete];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    NSString *message = NSLocalizedString(@"User notifications are working", nil);
    [self sendMessage:message title:nil complete:complete];
}

- (void)sendMessage:(NSString *)message title:(NSString *)title complete:(void (^)(NSError *))complete {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.informativeText = message;
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    complete(nil);
}

+ (void)sendNotificationOfTestEmailSuccess:(BOOL)success error:(NSError *)error
{
    if ([[self class] isEnabled]) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = NSLocalizedString(@"Email test completed.", @"NSUserNotification posted after test email is complete.");

        notification.informativeText = success ? NSLocalizedString(@"Successfully sent test email.", @"NSUserNotification text when email is successfully sent.") : NSLocalizedString(@"There was a problem sending test email. Double-check the SMTP settings you specified in AutoPkgr.", @"NSUserNotification text when email fails.");

        if (success) {
            [notification setHasActionButton:NO];
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
}

#pragma mark - NSUserNotificationDelegate
@end

@implementation LGUserNotificationsDelegate

- (instancetype)initAsDefaultCenterDelegate
{
    if (self = [super init]) {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    return self;
}

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
