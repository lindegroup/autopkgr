//
//  LGSlackNotification.m
//  AutoPkgr
//
//  Copyright 2015 The Linde Group, Inc.
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

#import "LGSlackNotification.h"
#import <AFNetworking/AFHTTPRequestOperationManager.h>

static NSString *const SlackLink = @"https://slack.com/channels";
static NSString *const SlacksNotificationsEnabledKey = @"SlackNotificationsEnabled";

@implementation LGSlackNotification

#pragma mark - Protocol Conforming
+ (NSString *)serviceDescription
{
    return NSLocalizedString(@"AutoPkgr Slack Bot", @"Slack webhook service description");
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:SlacksNotificationsEnabledKey];
}

+ (BOOL)storesInfoInKeychain
{
    return YES;
}

+ (NSString *)account
{
    return @"AutoPkgr Slack-Bot";
}

+ (NSURL *)serviceURL
{
    return [NSURL URLWithString:SlackLink];
}

+ (BOOL)templateIsFile
{
    return NO;
}

+ (NSString *)defaultTemplate
{
    return [self templateWithName:@"slack_report" type:@"md"];
}

+ (ACEMode)tempateFormat {
    return ACEModeMarkdown;
}

#pragma mark - Send
- (void)send:(void (^)(NSError *))complete
{
    NSString *message = [self.report renderWithTemplate:[[self class] reportTemplate] error:nil];
    [self sendMessage:message title:nil complete:complete];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    [self sendMessage:NSLocalizedString(@"You are now set up to receive notifications on your Slack channel!", nil) title:nil complete:complete];
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

    // Set up the request serializer with any additional criteria for slack
    //[manager.requestSerializer setAuthorizationHeaderFieldWithUsername:@"" password:@""]; <- probably don't need this.

    manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    return manager;
}

- (NSDictionary *)baseParameters:(NSDictionary *)parameters
{
    NSMutableDictionary *dict = [parameters mutableCopy];
    if (!parameters[@"username"]) {
        // "SlackBotName" is bound to TextField in Slack integration view controller.
        dict[@"username"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"SlackBotName"] ?: @"AutoPkgr";
    }

    dict[@"icon_url"] = @"https://raw.githubusercontent.com/lindegroup/autopkgr/master/AutoPkgr/Images.xcassets/AppIcon.appiconset/icon_32x32%402x.png";

    return [dict copy];
}

- (void)sendMessageWithParameters:(NSDictionary *)parameters
{
    AFHTTPRequestOperationManager *manager = [self requestManager];
    __weak typeof(self) weakSelf = self;
    [[self class] infoFromKeychain:^(NSString *webHookURL, NSError *error) {
        if (error) {
            weakSelf.notificatonComplete(error);
        } else {
            [manager POST:webHookURL
                parameters:[weakSelf baseParameters:parameters]
                success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    weakSelf.notificatonComplete(nil);
                }
                failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    NSLog(@"Error sending Slack notification: %@", operation.responseString);
                    weakSelf.notificatonComplete([LGError errorWithResponse:operation.response]);
                }];
        }
    }];
}

@end
