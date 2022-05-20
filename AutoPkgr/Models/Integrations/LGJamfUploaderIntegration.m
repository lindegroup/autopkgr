//
//  LGJamfUploaderIntegration.m
//  AutoPkgr
//
//  Copyright 2022 The Linde Group.
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

#import "LGIntegration+Protocols.h"
#import "LGJamfUploaderIntegration.h"
#import "LGLogger.h"
#import "LGServerCredentials.h"
#import <Foundation/Foundation.h>

@interface LGJamfUploaderIntegration () <LGIntegrationSharedProcessor>
@end

@implementation LGJamfUploaderIntegration

@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"JamfUploader";
}

+ (NSString *)credits
{
    return @"Graham Pugh\nhttp://www.apache.org/licenses/LICENSE-2.0\nhttps://github.com/autopkg/grahampugh-recipes";
}

+ (NSURL *)homePage
{
    return [NSURL URLWithString:@"https://github.com/autopkg/grahampugh-recipes"];
}

+ (NSString *)gitHubURL
{
    return @"https://github.com/autopkg/grahampugh-recipes";
}

+ (NSString *)defaultRepository
{
    return @"https://github.com/autopkg/grahampugh-recipes.git";
}

+ (NSString *)binary
{
    return nil;
}

+ (NSArray *)components
{
    return nil;
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (NSString *)summaryResultKey
{
    return @"jamfuploader_summary_result";
}

#pragma mark - Instance overrides.

- (void)customInstallActions:(void (^)(NSError *))reply
{
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
    NSNumber *verifySSL = [defaults autoPkgDomainObject:@"JAMF_VERIFY_SSL"];
    if (!verifySSL) {
        defaults.JAMFVerifySSL = YES;
    }
    reply(nil);
}

- (void)customUninstallActions:(void (^)(NSError *))reply
{
    // Clear out the defaults.
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
    defaults.JAMFAPIPassword = nil;
    defaults.JAMFAPIUsername = nil;
    defaults.JAMFRepos = nil;
    defaults.JAMFURL = nil;

    reply(nil);
}

@end

#pragma mark - LGDefaults category implementation for JamfUploader Interface

@implementation LGJamfUploaderDefaults

- (NSString *)JAMFURL
{
    return [self autoPkgDomainObject:@"JAMF_URL"];
}

- (void)setJAMFURL:(NSString *)JAMFURL
{
    [self setAutoPkgDomainObject:JAMFURL forKey:@"JAMF_URL"];
}

#pragma mark -
- (NSString *)JAMFAPIUsername
{
    return [self autoPkgDomainObject:@"API_USERNAME"];
}

- (void)setJAMFAPIUsername:(NSString *)JAMFAPIUsername
{
    [self setAutoPkgDomainObject:JAMFAPIUsername forKey:@"API_USERNAME"];
}

#pragma mark -
- (NSString *)JAMFAPIPassword
{
    return [self autoPkgDomainObject:@"API_PASSWORD"];
}

- (void)setJAMFAPIPassword:(NSString *)JAMFAPIPassword
{
    [self setAutoPkgDomainObject:JAMFAPIPassword forKey:@"API_PASSWORD"];
}

#pragma mark -
- (NSArray *)JAMFRepos
{
    return [self autoPkgDomainObject:@"JAMF_REPOS"];
}

- (void)setJAMFRepos:(NSArray *)JAMFRepos
{
    [self setAutoPkgDomainObject:JAMFRepos forKey:@"JAMF_REPOS"];
}

#pragma mark -
- (BOOL)JAMFVerifySSL
{
    NSNumber *verifySSL = [self autoPkgDomainObject:@"JAMF_VERIFY_SSL"];
    if (verifySSL == nil) {
        return YES;
    }

    return [verifySSL boolValue];
}

- (void)setJAMFVerifySSL:(BOOL)JAMFVerifySSL
{
    DevLog(@"Setting JAMF_SSL_VERIFY to %@", JAMFVerifySSL ? @"YES" : @"NO");
    [self setAutoPkgDomainObject:@(JAMFVerifySSL) forKey:@"JAMF_VERIFY_SSL"];
}

@end
