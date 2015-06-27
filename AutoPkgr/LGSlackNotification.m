// LGSlackNotification.m
//
// Copyright 2015 The Linde Group, Inc.
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

#import "LGSlackNotification.h"
#import <AFNetworking/AFHTTPRequestOperationManager.h>

@implementation LGSlackNotification

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
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SlackNotificationsEnabled"];
}

+ (BOOL)storesInfoInKeychain {
    return YES;
}

+ (NSString *)account {
    return @"AutoPkgr Slack-Bot";
}

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

- (void)webHookURL:(void(^)(NSString *))reply
{
    // This probably shouldn't be stored in defaults, but for testing now it's OK.
    [[self class] infoFromKeychain:^(NSString *webHookURL, NSError *error) {
        reply(webHookURL ?: @"");
    }];
}

- (NSDictionary *)baseParameters:(NSDictionary *)parameters {
    NSMutableDictionary *dict = [parameters mutableCopy];
    if (!parameters[@"username"]) {
        dict[@"username"] = @"AutoPkgr";
    }

    dict[@"icon_url"] = @"https://raw.githubusercontent.com/lindegroup/autopkgr/master/AutoPkgr/Images.xcassets/AppIcon.appiconset/icon_32x32%402x.png";

    return [dict copy];
}

- (void)send:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSMutableString *str = self.report.emailSubjectString.mutableCopy;
    [str appendString:@":\n"];

    [self.report.updatedApplications enumerateObjectsUsingBlock:^(LGUpdatedApplication *app, NSUInteger idx, BOOL *stop) {
        [str appendFormat:@" * %@ [%@]\n", app.name, app.version]; // Format howerver
    }];

    NSDictionary *slackParameters = @{ @"text" : str };

    [self sendMessageWithParameters:slackParameters];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSDictionary *testParameters = @{ @"text" : NSLocalizedString(@"You are now set up to receive notifications on your Slack channel!", nil) };

    [self sendMessageWithParameters:testParameters];
}

- (void)sendMessageWithParameters:(NSDictionary *)parameters
{
    AFHTTPRequestOperationManager *manager = [self requestManager];
    [self webHookURL:^(NSString *webHookURL) {
        [manager POST:webHookURL parameters:[self baseParameters:parameters] success:^(AFHTTPRequestOperation *operation, id responseObject) {
            self.notificatonComplete(nil);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"%@", operation.responseString);
            self.notificatonComplete(error);
        }];
    }];
}

@end
