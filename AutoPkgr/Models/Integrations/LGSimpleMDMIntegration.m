//
//  LGSimpleMDMIntegration.m
//  AutoPkgr
//
//  Copyright 2020 Shawn Honsberger
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
#import "LGSimpleMDMIntegration.h"
#import <Foundation/Foundation.h>

// Define the protocols you intend to conform to.
@interface LGSimpleMDMIntegration () <LGIntegrationPackageInstaller,
                                      LGIntegrationSharedProcessor>
                                     
@end

@implementation LGSimpleMDMIntegration
@synthesize installedVersion = _installedVersion;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"SimpleMDM plugin";
}

+ (NSString *)credits
{
    return @"Taylor Boyko\nhttps://github.com/SimpleMDM/munki-plugin";
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/SimpleMDM/munki-plugin/releases";
}

+ (NSString *)defaultRepository
{
    return @"https://github.com/SimpleMDM/munki-plugin.git";
}

+ (NSString *)binary
{
    return @"/usr/local/munki/munkilib/munkirepo/SimpleMDMRepo.py";
}

+ (NSArray *)components
{
    return @[
        [self binary],
         @"/usr/local/simplemdm/munki-plugin/config.plist",
    ];
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.simplemdm.munki_plugin" ];
}

+ (BOOL)isUninstallable
{
    return NO;
}

+ (NSString *)summaryResultKey
{
    return @"simplemdm_summary_result";
}
#pragma mark - Instance overrides
- (NSString *)installedVersion
{
    return [NSDictionary dictionaryWithContentsOfFile:@"/private/var/db/receipts/com.simplemdm.munki_plugin.plist"][@"PackageVersion"];
}

/**
 *  Any custom install actions that need to be taken.
 */
- (void)customInstallActions:(void (^)(NSError *error))reply
{
    reply(nil);
}

- (void)customUninstallActions:(void (^)(NSError *))reply
{
    LGSimpleMDMDefaults *defaults = [LGSimpleMDMDefaults new];
    // Set preferences back to their default settings.
    defaults.SIMPLEMDM_API_KEY = nil;

    reply(nil);
}

@end

@implementation LGSimpleMDMDefaults

// SIMPLEMDM_API_KEY

- (NSString *)SIMPLEMDM_API_KEY
{
    return [self simpleMDMDomainObject:NSStringFromSelector(@selector(key))];
}

- (void)setSIMPLEMDM_API_KEY:(NSString *)SIMPLEMDM_API_KEY
{
    [self setSimpleMDMDomainObject:SIMPLEMDM_API_KEY forKey:NSStringFromSelector(@selector(key))];
}

@end
