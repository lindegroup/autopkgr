//
//  LGNotificationService.m
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

#pragma mark - Template
+ (NSString *)_reportTemplateKey
{
    return quick_formatString(@"%@%@", NSStringFromSelector(@selector(reportTemplate)).uppercaseString, [self className]);
}

+ (NSString *)_reportTemplateFile
{
    NSString *className = [self className];
    NSRange r1 = [className rangeOfString:@"LG"];
    NSRange r2 = [className rangeOfString:@"Notification"];
    NSRange rSub = NSMakeRange(r1.location + r1.length, r2.location - r1.location - r1.length);
    NSString *base = [[className substringWithRange:rSub] stringByAppendingString:@"_report.html"];
    return [[LGHostInfo getAppSupportDirectory] stringByAppendingPathComponent:[base lowercaseString]];
}

+ (NSString *)reportTemplate
{
    NSError *error = nil;
    NSString *reportTemplate = nil;
    if ([[self class] templateIsFile]) {
        NSString *file = [self _reportTemplateFile];
        if([[NSFileManager defaultManager] fileExistsAtPath:file]){
            reportTemplate = [NSString stringWithContentsOfFile:file
                                                       encoding:NSUTF8StringEncoding error:&error];
        }
    } else {
        reportTemplate = [[NSUserDefaults standardUserDefaults] stringForKey:[self _reportTemplateKey]];
    }
    if (error) {
        NSLog(@"%@", error);
    }
    return reportTemplate ?: [(id<LGNotificationServiceProtocol>)self defaultTemplate];
};

+ (void)setReportTemplate:(NSString *)reportTemplate
{
    NSError *error = nil;
    if ([[self class] templateIsFile]) {
        if (!reportTemplate) {
            [[NSFileManager defaultManager] removeItemAtPath:[self _reportTemplateFile] error:&error];
        } else  {
            [reportTemplate writeToFile:[self _reportTemplateFile] atomically:YES encoding:NSUTF8StringEncoding error:&error];
        }
    } else {
        [[NSUserDefaults standardUserDefaults] setValue:reportTemplate forKey:[self _reportTemplateKey]];
    }
    if (error) {
        NSLog(@"%@", error);
    }
}

+ (ACEMode)tempateFormat {
    return ACEModeHTML;
}

+ (NSString *)templateWithName:(NSString *)name type:(NSString *)type
{
    NSString *dataFile = [[NSBundle mainBundle] pathForResource:name ofType:type];
    return  [NSString stringWithContentsOfFile:dataFile encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - Send
- (void)send:(void (^)(NSError *))complete
{
    subclassMustImplement(self, _cmd);
}

- (void)sendTest:(void (^)(NSError *))complete
{
    subclassMustImplement(self, _cmd);
}

- (void)sendMessage:(NSString *)message title:(NSString *)title complete:(void (^)(NSError *))complete {
    subclassMustImplement(self, _cmd);
}

@end
