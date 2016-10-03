//
//  LGFileWaveIntegration.m
//  AutoPkgr
//
//  Copyright 2015 Elliot Jordan
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

#import "LGFileWaveIntegration.h"
#import "LGIntegration+Protocols.h"
#import "NSString+versionCompare.h"

@interface LGFileWaveIntegration () <LGIntegrationSharedProcessor>
@end

@implementation LGFileWaveIntegration

+ (NSString *)name
{
    return @"FileWaveImporter";
}

+ (NSString *)credits
{
    return @"Copyright 2015 FileWave (Europe) GmbH\nhttp://www.apache.org/licenses/LICENSE-2.0";
}

+ (NSString *)defaultRepository
{
    return @"https://github.com/autopkg/filewave.git";
}

+ (NSURL *)homePage
{
    return [NSURL URLWithString:@"https://github.com/autopkg/filewave"];
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (NSString *)summaryResultKey
{
    return @"filewave_summary_result";
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error
{
    NSError *err = nil;
    NSString *fwAdmin = @"/Applications/FileWave/FileWave Admin.app";
    NSString *bundleVersionKey = @"CFBundleVersion";

    NSBundle *bundle = [NSBundle bundleWithPath:fwAdmin];
    if (!bundle) {
        err = [[self class] requirementsError:@"FileWave Admin.app is not installed"];
    }
    else {
        NSString *version = bundle.infoDictionary[bundleVersionKey];
        if ([version version_isLessThan:@"10.0"]) {
            err = [[self class] requirementsError:@"FileWave Admin version 10.0 or greater required."];
        }
    }
    if (err && error) {
        *error = err;
    }
    return err ? NO : YES;
}

- (void)customUninstallActions:(void (^)(NSError *))reply
{
    LGFileWaveDefaults *defaults = [LGFileWaveDefaults new];
    defaults.FW_SERVER_HOST = nil;
    defaults.FW_SERVER_PORT = nil;
    defaults.FW_ADMIN_USER = nil;
    defaults.FW_ADMIN_PASSWORD = nil;

    reply(nil);
}

@end

@implementation LGFileWaveDefaults
// URL
- (NSString *)FW_SERVER_HOST
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(FW_SERVER_HOST))];
}

- (void)setFW_SERVER_HOST:(NSString *)FW_SERVER_HOST
{
    [self setAutoPkgDomainObject:FW_SERVER_HOST forKey:NSStringFromSelector(@selector(FW_SERVER_HOST))];
}

// PORT
- (NSString *)FW_SERVER_PORT
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(FW_SERVER_PORT))];
}

- (void)setFW_SERVER_PORT:(NSString *)FW_SERVER_PORT
{
    [self setAutoPkgDomainObject:FW_SERVER_PORT forKey:NSStringFromSelector(@selector(FW_SERVER_PORT))];
}

// USER
- (NSString *)FW_ADMIN_USER
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(FW_ADMIN_USER))];
}

- (void)setFW_ADMIN_USER:(NSString *)FW_ADMIN_USER
{
    [self setAutoPkgDomainObject:FW_ADMIN_USER forKey:NSStringFromSelector(@selector(FW_ADMIN_USER))];
}

// PASSWORD
- (NSString *)FW_ADMIN_PASSWORD
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(FW_ADMIN_PASSWORD))];
}

- (void)setFW_ADMIN_PASSWORD:(NSString *)FW_ADMIN_PASSWORD
{
    [self setAutoPkgDomainObject:FW_ADMIN_PASSWORD forKey:NSStringFromSelector(@selector(FW_ADMIN_PASSWORD))];
}

@end
