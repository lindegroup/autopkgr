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
    return NSLocalizedString(@"Slack Bot", @"Slack webhook service description");
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"SlackNotificationsEnabled"];
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

    manager.responseSerializer = [AFJSONResponseSerializer serializer];

    return manager;
}

- (NSString *)webHookURL
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"SlackWebhookURL"] ?: @"";
}

- (void)send:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSString *body = self.report.emailSubjectString;

    NSMutableString *str = [[NSMutableString alloc] init];
    [self.report.updatedApplications enumerateObjectsUsingBlock:^(LGUpdatedApplication *app, NSUInteger idx, BOOL *stop) {
        [str appendFormat:@"App: %@ [%@]\n", app.name, app.version]; // Format howerver
    }];

    NSDictionary *slackParameters = @{ @"payload" : @{
        @"text" : body, // <-- not correct!
        @"user" : @"slack-bot", // <-- not correct!
    }
    };

    [self sendMessageWithParameters:slackParameters];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSDictionary *testParameters = @{}; // some sort of test values
    [self sendMessageWithParameters:testParameters];
}

- (void)sendMessageWithParameters:(NSDictionary *)parameters
{
    AFHTTPRequestOperationManager *manager = [self requestManager];
    NSString *webHookURL = [self webHookURL];

    [manager POST:webHookURL parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
        self.notificatonComplete(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        self.notificatonComplete(error);
    }];
}
@end
