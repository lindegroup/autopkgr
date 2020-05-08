//
//  LGAbsoluteManageIntegration.m
//  AutoPkgr
//
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "LGAbsoluteManageIntegration.h"
#import "LGIntegration+Protocols.h"

// Define the protocols you intend to conform to.
@interface LGAbsoluteManageIntegration () <LGIntegrationPackageInstaller, LGIntegrationSharedProcessor>
@end

#pragma mark - Integration overrides
@implementation LGAbsoluteManageIntegration

// Since this is defined using a protocol, it needs to be synthesized.
// If not conforming to LGIntegrationPackageInstaller remove it.
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"AbsoluteManageExport";
}

+ (NSString *)shortName
{
    return @"AMExport";
}
+ (NSString *)credits
{
    return @"Thomas Burgin\nhttp://www.apache.org/licenses/LICENSE-2.0\nhttps://github.com/tburgin/AbsoluteManageExport";
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/tburgin/AbsoluteManageExport/releases";
}

+ (NSString *)defaultRepository
{
    // Not sure what the "Official" default repo is yet.
    return @"https://github.com/tburgin/AbsoluteManageExport.git";
}

+ (NSArray *)components
{
    return @[ [self binary] ];
}

+ (NSString *)binary
{
    return @"/Library/AutoPkg/autopkglib/AbsoluteManageExport.py";
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.tburgin.AbsoluteManageExport" ];
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (NSString *)summaryResultKey
{
    return @"absolute_manage_export_summary_result";
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *lanRev = @"/Applications/LANrev Admin.app";

    LGAbsoluteManageDefaults *defaults = [LGAbsoluteManageDefaults new];

    NSString *dataBase = defaults.DatabaseDirectory ?: @"~/Library/Application Support/LANrev Admin/Database/".stringByExpandingTildeInPath;

    for (NSString *path in @[ lanRev, dataBase ]) {
        if (![manager fileExistsAtPath:path]) {
            if (error) {
                *error = [[self class] requirementsError:[NSString stringWithFormat:@"Please check that %@ exists.", path]];
            }
            return NO;
        }
    }

    return YES;
}

#pragma mark - Instance overrides
- (NSString *)installedVersion
{
    NSString *receipt = @"/private/var/db/receipts/com.github.tburgin.AbsoluteManageExport.plist";
    return [NSDictionary dictionaryWithContentsOfFile:receipt][@"PackageVersion"];
}

- (void)customInstallActions
{
    [[LGAbsoluteManageDefaults new] setAllowURLSDPackageImport:YES];
}

@end

#pragma mark - Defaults
@implementation LGAbsoluteManageDefaults

static NSString *const kLGAbsoluteManageDomain = @"com.poleposition-sw.lanrev_admin";

- (NSString *)DatabaseDirectory
{
    return [self absoluteManageDomainObject:
                     NSStringFromSelector(@selector(DatabaseDirectory))];
}

- (void)setAllowURLSDPackageImport:(BOOL)AllowURLSDPackageImport
{
    [self setAbsoluteManageDomainObject:@(AllowURLSDPackageImport)
                                 forKey:NSStringFromSelector(@selector(AllowURLSDPackageImport))];
}

- (BOOL)AllowURLSDPackageImport
{
    return [[self absoluteManageDomainObject:
                      NSStringFromSelector(@selector(AllowURLSDPackageImport))] boolValue];
}

- (id)absoluteManageDomainObject:(NSString *)key
{
    id value = CFBridgingRelease(
        CFPreferencesCopyAppValue((__bridge CFStringRef)(key),
                                  (__bridge CFStringRef)(kLGAbsoluteManageDomain)));
    return value;
}

- (void)setAbsoluteManageDomainObject:(id)object forKey:(NSString *)key
{
    CFPreferencesSetAppValue((__bridge CFStringRef)(key),
                             (__bridge CFTypeRef)(object),
                             (__bridge CFStringRef)(kLGAbsoluteManageDomain));
}

@end
