//
//  LGLANrevImporterIntegration.m
//  AutoPkgr
//
//  Created by Elliot Jordan on 2/23/2016.
//  Copyright 2016 Elliot Jordan.
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

#import "LGLANrevImporterIntegration.h"
#import "LGIntegration+Protocols.h"

// Define the protocols you intend to conform to...
@interface LGLANrevImporterIntegration () <LGIntegrationPackageInstaller, LGIntegrationSharedProcessor>
@end

#pragma mark - Integration overrides
@implementation LGLANrevImporterIntegration

// Since this is defined using a protocol, it needs to be synthesized...
// If not conforming to LGIntegrationPackageInstaller remove it.
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"LANrevImporter";
}

+ (NSString *)shortName
{
    return @"LANrevImporter";
}
+ (NSString *)credits {
    return @"Copyright 2016 Jeremy Baker\nhttp://www.apache.org/licenses/LICENSE-2.0";
}

+ (NSURL *)homePage {
    return [NSURL URLWithString:@"https://github.com/jbaker10/LANrevImporter"];
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/jbaker10/LANrevImporter/releases";
}

+ (NSString *)defaultRepository
{
    // Not sure what the "Official" default repo is yet.
    return @"https://github.com/jbaker10/LANrevImporter.git";
}

+ (NSArray *)components
{
    // If there's not a binary don't include it here!!
    return @[[self binary]];
}

+ (NSString *)binary
{
    return @"/Library/AutoPkg/autopkglib/LANrevImporter.py";
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.jbaker10.LANrevImporterInstaller" ];
}

+ (BOOL)isUninstallable {
    return YES;
}

+ (NSString *)summaryResultKey {
    return @"lanrev_importer_summary_result";
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *lanRev = @"/Applications/LANrev Admin.app";

    LGLANrevImporterDefaults *defaults = [LGLANrevImporterDefaults new];

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
    NSString *receipt = @"/private/var/db/receipts/com.github.jbaker10.LANrevImporterInstaller.plist";
    return [NSDictionary dictionaryWithContentsOfFile:receipt][@"PackageVersion"];
}

- (void)customInstallActions {
    [[LGLANrevImporterDefaults new] setAllowURLSDPackageImport:YES];
}

@end

#pragma mark - Defaults
@implementation LGLANrevImporterDefaults

static NSString *const kLGLANrevImporterDomain = @"com.poleposition-sw.lanrev_admin";

- (NSString *)DatabaseDirectory {
    return [self LANrevDomainObject:
             NSStringFromSelector(@selector(DatabaseDirectory))];
}

- (void)setAllowURLSDPackageImport:(BOOL)AllowURLSDPackageImport
{
    [self setLANrevImporterDomainObject:@(AllowURLSDPackageImport)
                                 forKey:NSStringFromSelector(@selector(AllowURLSDPackageImport))];
}

- (BOOL)AllowURLSDPackageImport
{
    return [[self LANrevDomainObject:
                      NSStringFromSelector(@selector(AllowURLSDPackageImport))] boolValue];
}

- (id)LANrevDomainObject:(NSString *)key
{
    id value = CFBridgingRelease(
        CFPreferencesCopyAppValue((__bridge CFStringRef)(key),
                                  (__bridge CFStringRef)(kLGLANrevImporterDomain)));
    return value;
}

- (void)setLANrevImporterDomainObject:(id)object forKey:(NSString *)key
{
    CFPreferencesSetAppValue((__bridge CFStringRef)(key),
                             (__bridge CFTypeRef)(object),
                             (__bridge CFStringRef)(kLGLANrevImporterDomain));
}

@end
