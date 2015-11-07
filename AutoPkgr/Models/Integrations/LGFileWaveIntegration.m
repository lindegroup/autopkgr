//
//  LGFileWaveIntegration.m
//  AutoPkgr
//
//  Copyright 2015 Elliot Jordan.
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

// Define the protocols you intend to conform to...
@interface LGFileWaveIntegration () <LGIntegrationPackageInstaller, LGIntegrationSharedProcessor>
@end

#pragma mark - Integration overrides
@implementation LGFileWaveIntegration

// Since this is defined using a protocol, it needs to be synthesized...
// If not conforming to LGIntegrationPackageInstaller remove it.
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"FileWaveImporter";
}

+ (NSString *)shortName
{
    return @"FileWaveImporter";
}
+ (NSString *)credits {
    return @"Copyright 2015 FileWave (Europe) GmbH\nhttp://www.apache.org/licenses/LICENSE-2.0";
}

+ (NSURL *)homePage {
    return [NSURL URLWithString:@"https://github.com/autopkg/filewave"];
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/autopkg/filewave/releases";
}

+ (NSString *)defaultRepository
{
    // Not sure what the "Official" default repo is yet.
    return @"https://github.com/autopkg/filewave.git";
}

+ (NSArray *)components
{
    // If there's not a binary don't include it here!!
    return @[[self binary]];
}

+ (NSString *)binary
{
    return @"/Library/AutoPkg/autopkglib/FileWaveImporter.py";
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.autopkg.filewave.FWTool" ];
}

+ (BOOL)isUninstallable {
    return YES;
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *lanRev = @"/Applications/LANrev Admin.app";

    LGFileWaveDefaults *defaults = [LGFileWaveDefaults new];

    NSString *dataBase = defaults.DatabaseDirectory ?: @"~/Library/Application Support/LANrev Admin/Database/".stringByExpandingTildeInPath;

    for (NSString* path in @[lanRev, dataBase]) {
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
    NSString *receipt = @"/private/var/db/receipts/com.github.autopkg.filewave.FWTool.plist";
    return [NSDictionary dictionaryWithContentsOfFile:receipt][@"PackageVersion"];
}

- (void)customInstallActions {
    [[LGFileWaveDefaults new] setAllowURLSDPackageImport:YES];
}

@end

#pragma mark - Defaults
@implementation LGFileWaveDefaults

static NSString *const kLGFileWaveDomain = @"com.poleposition-sw.lanrev_admin";

- (NSString *)DatabaseDirectory {
    return [self filewaveDomainObject:
             NSStringFromSelector(@selector(DatabaseDirectory))];
}

- (void)setAllowURLSDPackageImport:(BOOL)AllowURLSDPackageImport
{
    [self setFileWaveDomainObject:@(AllowURLSDPackageImport)
                                 forKey:NSStringFromSelector(@selector(AllowURLSDPackageImport))];
}

- (BOOL)AllowURLSDPackageImport
{
    return [[self filewaveDomainObject:
                      NSStringFromSelector(@selector(AllowURLSDPackageImport))] boolValue];
}

- (id)filewaveDomainObject:(NSString *)key
{
    id value = CFBridgingRelease(
        CFPreferencesCopyAppValue((__bridge CFStringRef)(key),
                                  (__bridge CFStringRef)(kLGFileWaveDomain)));
    return value;
}

- (void)setFileWaveDomainObject:(id)object forKey:(NSString *)key
{
    CFPreferencesSetAppValue((__bridge CFStringRef)(key),
                             (__bridge CFTypeRef)(object),
                             (__bridge CFStringRef)(kLGFileWaveDomain));
}

@end
