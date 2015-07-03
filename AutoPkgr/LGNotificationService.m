//
//  LGNotificatonService.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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
#import "LGPasswords.h"
#import "LGError.h"

@implementation LGNotificationService

- (instancetype)initWithReport:(LGAutoPkgReport *)report
{
    if (self = [self init]) {
        _report = report;
    }
    return self;
}

+ (NSString *)serviceDescription
{
    subclassMustImplement(self, _cmd);
    return @"";
}

+ (BOOL)isEnabled
{
    subclassMustImplement(self, _cmd);
    return NO;
}

+ (BOOL)reportsIntegrations
{
    return NO;
}

+ (BOOL)storesInfoInKeychain
{
    return NO;
}

+ (NSString *)account
{
    if ([[self class] storesInfoInKeychain]) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)keychainServiceDescription
{
    return [self serviceDescription];
}

+ (NSString *)keychainServiceLabel
{
    return nil;
}

+ (void)infoFromKeychain:(void (^)(NSString *, NSError *))reply
{
    if ([[self class] storesInfoInKeychain]) {
        NSString *service = [[self class] keychainServiceDescription];
        NSString *label = [[self class] keychainServiceLabel];
        NSString *account = [[self class] account];
        [LGPasswords getPasswordForAccount:account service:service label:label reply:reply];
    } else {
        return reply(nil, nil);
    }
}

+ (void)saveInfoToKeychain:(NSString *)info reply:(void (^)(NSError *))reply
{
    if ([[self class] storesInfoInKeychain]) {
        NSString *service = [[self class] keychainServiceDescription];
        NSString *label = [[self class] keychainServiceLabel];
        NSString *account = [[self class] account];
        [LGPasswords savePassword:info forAccount:account service:service label:label reply:reply];
    } else {
        return reply(nil);
    }
}

- (void)send:(void (^)(NSError *))complete
{
    subclassMustImplement(self, _cmd);
}

- (void)sendTest:(void (^)(NSError *))complete
{
    subclassMustImplement(self, _cmd);
}
@end
