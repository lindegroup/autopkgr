//
//  LGDefaults+JSSImporter.m
//  AutoPkgr
//
//  Created by Eldon on 10/3/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGDefaults+JSSImporter.h"

# pragma mark - Repo Keys
NSString *const kLGJSSDistPointNameKey = @"name";
NSString *const kLGJSSDistPointURLKey = @"URL";
NSString *const kLGJSSDistPointSharePointKey = @"share_name";
NSString *const kLGJSSDistPointPortKey = @"port";
NSString *const kLGJSSDistPointUserNameKey = @"username";
NSString *const kLGJSSDistPointPasswordKey = @"password";
NSString *const kLGJSSDistPointWorkgroupDomainKey = @"domain";
NSString *const kLGJSSDistPointTypeKey = @"type";

#pragma mark - LGDefaults category implementation for JSSImporter Interface

@implementation LGDefaults (JSSImporter)

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
    return [verifySSL boolValue];
}

- (void)setJSSVerifySSL:(BOOL)JSSVerifySSL
{
    [self setAutoPkgDomainObject:@(JSSVerifySSL) forKey:@"JSS_VERIFY_SSL"];
}

@end