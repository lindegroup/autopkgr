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
@synthesize installedVersion = _installedVersion;

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
    static NSString *const jamfUploaderBinary = @"~/Library/AutoPkg/RecipeRepos/com.github.autopkg.grahampugh-recipes/JamfUploaderProcessors/JamfUploaderLib/JamfUploaderBase.py";
    return jamfUploaderBinary.stringByExpandingTildeInPath;
}

+ (NSArray *)components
{
    return @[
        [self binary],
    ];
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.autopkg.grahampugh-recipes"];
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

- (NSString *)installedVersion
{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *receipt = @"~/Library/AutoPkg/RecipeRepos/com.github.autopkg.grahampugh-recipes/JamfUploaderProcessors/JamfUploaderLib/JamfUploaderBase.py";


    if ([[self class] isInstalled]) {
        if ([fm fileExistsAtPath:receipt]) {
        }
        _installedVersion = @"is";
    }

    return _installedVersion;
}

- (void)customInstallActions:(void (^)(NSError *))reply
{
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
    NSNumber *verifySSL = [defaults autoPkgDomainObject:@"JSS_VERIFY_SSL"];
    if (!verifySSL) {
        defaults.JSSVerifySSL = YES;
    }
    reply(nil);
}

- (void)customUninstallActions:(void (^)(NSError *))reply
{
    // Clear out the defaults.
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
    defaults.JSSAPIPassword = nil;
    defaults.JSSAPIUsername = nil;
    defaults.JSSRepos = nil;
    defaults.JSSURL = nil;

    reply(nil);
}

@end

#pragma mark - LGDefaults category implementation for JamfUploader Interface

@implementation LGJamfUploaderDefaults

- (NSString *)JSSURL
{
    return [self autoPkgDomainObject:@"JSS_URL"];
}

- (void)setJSSURL:(NSString *)JSSURL
{
    [self setAutoPkgDomainObject:JSSURL forKey:@"JSS_URL"];
}

#pragma mark -
- (NSString *)JSSAPIUsername
{
    return [self autoPkgDomainObject:@"API_USERNAME"];
}

- (void)setJSSAPIUsername:(NSString *)JSSAPIUsername
{
    [self setAutoPkgDomainObject:JSSAPIUsername forKey:@"API_USERNAME"];
}

#pragma mark -
- (NSString *)JSSAPIPassword
{
    return [self autoPkgDomainObject:@"API_PASSWORD"];
}

- (void)setJSSAPIPassword:(NSString *)JSSAPIPassword
{
    [self setAutoPkgDomainObject:JSSAPIPassword forKey:@"API_PASSWORD"];
}

#pragma mark -
- (NSArray *)JSSRepos
{
    return [self autoPkgDomainObject:@"JSS_REPOS"];
}

- (void)setJSSRepos:(NSArray *)JSSRepos
{
    [self setAutoPkgDomainObject:JSSRepos forKey:@"JSS_REPOS"];
}

#pragma mark -
- (BOOL)JSSVerifySSL
{
    NSNumber *verifySSL = [self autoPkgDomainObject:@"JSS_VERIFY_SSL"];
    if (verifySSL == nil) {
        return YES;
    }

    return [verifySSL boolValue];
}

- (void)setJSSVerifySSL:(BOOL)JSSVerifySSL
{
    DevLog(@"Setting JSS_SSL_VERIFY to %@", JSSVerifySSL ? @"YES" : @"NO");
    [self setAutoPkgDomainObject:@(JSSVerifySSL) forKey:@"JSS_VERIFY_SSL"];
}

@end
