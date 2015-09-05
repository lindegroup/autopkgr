//
//  LGHipChatNotification.m
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

#import "LGHipChatNotification.h"
#import "LGDefaults.h"

#import <AFNetworking/AFHTTPRequestOperationManager.h>

static NSString *const HipChatLink = @"https://hipchat.com/rooms";

static NSString *const HipChatNotificationEnabledKey = @"HipChatNotificationsEnabled";
static NSString *const HipChatNotificationRoomKey = @"HipChatNotificationRoom";
static NSString *const HipChatNotificationNotifyKey = @"HipChatNotificationNotify";


@implementation LGHipChatNotification

#pragma mark - Protocol Conforming
+ (NSString *)serviceDescription
{
    return @"AutoPkgr HipChat";
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:HipChatNotificationEnabledKey];
}

+ (BOOL)storesInfoInKeychain
{
    return YES;
}

+ (NSString *)account
{
    return @"AutoPkgr HipChat API Token";
}

+ (NSURL *)serviceURL
{
    return [NSURL URLWithString:HipChatLink];
}

#pragma mark - Send
- (void)send:(void (^)(NSError *))complete
{
    self.notificatonComplete = complete;

    NSString *color;
    if (self.report.error) {
        color = @"red";
    } else {
        color = @"green";
    }

    NSDictionary *parameters = @{ @"message" : self.report.webChannelMessageString,
                                  @"color" : color,
                                  @"message_format" : @"text"
                                  };

    [self sendMessageWithParameters:[self baseRoomPostParameters:parameters]];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    self.notificatonComplete = complete;
    NSString *message = NSLocalizedString(@"Testing HipChat notifications!",
                                          @"HipChat testing message");

    NSDictionary *parameters = @{ @"message" : message };

    [self sendMessageWithParameters:[self baseRoomPostParameters:parameters]];
}

#pragma mark - Private
- (NSURL *)hipChatURL
{
    return [NSURL URLWithString:@"https://api.hipchat.com/v2/room/"];
}

- (NSString *)sendNotificationPath
{
    /* Get the room from defaults, or if not found use `__void` to cause
     * the request operation to fail without raising an exception */
    NSString *room = [[NSUserDefaults standardUserDefaults] stringForKey:HipChatNotificationRoomKey] ?: @"__void";
    return [room stringByAppendingPathComponent:@"notification"];
}

- (NSDictionary *)baseRoomPostParameters:(NSDictionary *)dictionary
{
    NSMutableDictionary *parameters = [dictionary mutableCopy];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSNumber *verify;
    if ((verify = [defaults valueForKey:HipChatNotificationNotifyKey])) {
        parameters[@"notify"] = verify;
    }

    return [parameters copy];
}

- (void)requestManager:(void (^)(AFHTTPRequestOperationManager *manager, NSError *error))reply
{
    [[self class] infoFromKeychain:^(NSString *token, NSError *error) {
        if (error) {
            reply(nil, error);
        } else {
            AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[self hipChatURL]];

            manager.requestSerializer = [AFJSONRequestSerializer serializer];
            manager.requestSerializer.timeoutInterval = 5;
            [manager.requestSerializer setValue:[@"Bearer " stringByAppendingString:token]
                         forHTTPHeaderField:@"Authorization"];

            manager.responseSerializer = [AFJSONResponseSerializer serializer];
            reply(manager, nil);
        }
    }];
}

- (void)sendMessageWithParameters:(NSDictionary *)parameters
{
    [self requestManager:^(AFHTTPRequestOperationManager *manager, NSError *error) {
        if (error) {
            // Error here means there was a problem getting the password.
            self.notificatonComplete(error);
        } else {
            NSString *urlString  = [[self sendNotificationPath] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            
            [manager POST:urlString parameters:parameters success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //
                self.notificatonComplete(nil);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                //
                self.notificatonComplete([LGError errorWithResponse:operation.response]);
            }];
        }
    }];
}
@end
