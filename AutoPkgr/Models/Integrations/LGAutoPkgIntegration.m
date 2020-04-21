//
//  LGAutoPkgIntegration.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGAutoPkgIntegration.h"
#import "LGAutoPkgTask.h"
#import "LGIntegration+Protocols.h"

@interface LGAutoPkgIntegration () <LGIntegrationPackageInstaller>
@end

@implementation LGAutoPkgIntegration
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"AutoPkg";
}

+ (NSString *)credits
{
    return @"Greg Neagle, Tim Sutton, Per Olofsson, Nick McSpadden, Elliot Jordan\nhttp://www.apache.org/licenses/LICENSE-2.0\nhttps://github.com/autopkg/autopkg";
}

+ (NSArray *)components
{
    return @[ self.binary ];
}

+ (NSString *)binary
{
    return @"/usr/local/bin/autopkg";
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/autopkg/autopkg/releases";
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.autopkg.autopkg" ];
}

+ (BOOL)isUninstallable
{
    return NO;
}

#pragma mark - Instance overrides
- (NSString *)installedVersion
{
    return [LGAutoPkgTask version];
}

@end
