//
//  LGGoogleHangoutsNotification.m
//  AutoPkgr
//
//  Created by Shawn Honsberger on 5/19/20.
//  Copyright © 2020 The Linde Group, Inc.
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

#import "LGGoogleHangoutsNotification.h"

#import <AFNetworking/AFHTTPRequestOperationManager.h>

static NSString *const GoogleHangoutsLink = @"https://developers.google.com/hangouts/chat/reference/message-formats";

static NSString *const GoogleHangoutsNotificationEnabledKey = @"GoogleHangoutsNotificationsEnabled";


@implementation LGGoogleHangoutsNotification

#pragma mark - Protocol Conforming
+ (NSString *)serviceDescription
{
    return @"AutoPkgr Google Chat";
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:GoogleHangoutsNotificationEnabledKey];
}

+ (BOOL)storesInfoInKeychain
{
    return YES;
}

+ (NSString *)account
{
    return @"AutoPkgr Google Chat Webhook URL";
}

+ (NSURL *)serviceURL
{
    return [NSURL URLWithString:GoogleHangoutsLink];
}

+ (BOOL)templateIsFile
{
    return NO;
}

+ (NSString *)defaultTemplate
{
    return [self templateWithName:@"slack_report" type:@"md"];
}

#pragma mark - Send
- (void)send:(void (^)(NSError *))complete
{
    NSString *message = [self.report renderWithTemplate:[[self class] reportTemplate] error:nil];
    [self sendMessage:message title:nil complete:complete];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    [self sendMessage:NSLocalizedString(@"You are now set up to receive notifications in your Google Chat room!", nil) title:nil complete:complete];
}

- (void)sendMessage:(NSString *)message title:(NSString *)title complete:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }
    [self sendMessageWithParameters:@{ @"text" : message }];
}

#pragma mark - Private

- (AFHTTPRequestOperationManager *)requestManager
{
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] init];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    manager.requestSerializer.timeoutInterval = 10; // This could be changed.

    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    return manager;
}

- (void)sendMessageWithParameters:(NSDictionary *)parameters
{
    AFHTTPRequestOperationManager *manager = [self requestManager];

    [[self class] infoFromKeychain:^(NSString *webHookURL, NSError *error) {
        if (error) {
            self.notificatonComplete(error);
        }
        else {
            [manager POST:webHookURL
                  parameters:parameters
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                      self.notificatonComplete(nil);
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                      NSLog(@"Error sending Google notification: %@", operation.responseString);
                      self.notificatonComplete([LGError errorWithResponse:operation.response]);
                  }];
        }
    }];
    
    

}

@end


