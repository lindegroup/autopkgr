//
//  LGMunkiIntegration.m
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

#import "LGMunkiIntegration.h"
#import "LGIntegration+Protocols.h"

static NSString *const kLGMunkiimportDomain = @"com.googlecode.munki.munkiimport";
// Define the protocols you intend to conform to...
@interface LGMunkiIntegration ()<LGIntegrationPackageInstaller, LGIntegrationSharedProcessor>
@end

#pragma mark - Tool overrides
@implementation LGMunkiIntegration

// Since this is defined using a protocol, it needs to be synthesized...
// If not conforming to LGToolPackageInstaller remove it.
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"Munki tools";
}

+ (NSString *)credits {
    return @"Copyright 2008-2014 Greg Neagle.\nhttp://www.apache.org/licenses/LICENSE-2.0";
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/munki/munki/releases";
}

+ (NSURL *)homePage {
    return [NSURL URLWithString:@"https://www.munki.org/"];
}

+ (NSString *)defaultRepository {
    return @"https://github.com/autopkg/recipes.git";
}

+ (NSArray *)components
{
    // If there's not a binary don't include it here!!
    return @[[self binary]
              ];
}

+ (NSString *)binary
{
    return @"/usr/local/munki/munkiimport";
}

+ (NSArray *)packageIdentifiers
{
    return @[@"com.googlecode.munki.admin",
             @"com.googlecode.munki.app",
             @"com.googlecode.munki.core",
             @"com.googlecode.munki.launchd",
             @"com.googlecode.munki.munkiwebadmin-scripts"];
}

+ (BOOL)isUninstallable {
    // There are just too many parts to try and uninstall munki
    return NO;
}

+ (NSString *)summaryResultKey {
    return @"munki_importer_summary_result";
}

- (void)customInstallActions {
    // TODO: Possibly setup a basic folder structure for munki.
}

#pragma mark - Instance overrides
- (NSString *)installedVersion
{
    return [[self versionTaskWithExec:[[self class] binary] arguments:@[ @"--version" ]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)remoteVersion {
    // Since the tag version is a short version, we need to use the string from the download package.
    NSString *pkgString = self.gitHubInfo.latestReleaseDownload.lastPathComponent;

    // This is where we start:  munkitools-2.2.4.2431.pkg
    return [pkgString.stringByDeletingPathExtension stringByReplacingOccurrencesOfString:@"munkitools-" withString:@""];

}

@end


#pragma mark - Defaults
@implementation LGDefaults (munki)

#pragma mark - Default catalog
-(void)setDefault_catalog:(NSString *)default_catalog {
    [self setMunkiDomainObject:default_catalog forKey:NSStringFromSelector(@selector(default_catalog))];
}

- (NSString *)default_catalog {
    return [self munkiimporterDomainObject:NSStringFromSelector(_cmd)];
}

#pragma mark - Editor
-(void)setEditor:(NSString *)editor {
    [self setMunkiDomainObject:editor forKey:NSStringFromSelector(@selector(editor))];
}

- (NSString *)editor {
    return [self munkiimporterDomainObject:NSStringFromSelector(_cmd)];
}

#pragma mark - Pkginfo extension
- (void)setPkginfo_extension:(NSString *)pkginfo_extension {
    [self setMunkiDomainObject:pkginfo_extension forKey:NSStringFromSelector(@selector(pkginfo_extension))];
}

-(NSString *)pkginfo_extension {
    return [self munkiimporterDomainObject:NSStringFromSelector(_cmd)];
}

#pragma mark - repo path
-(void)setRepo_path:(NSString *)repo_path {
    [self setMunkiDomainObject:repo_path forKey:NSStringFromSelector(@selector(repo_path))];
}

-(NSString *)repo_path {
    return [self munkiimporterDomainObject:NSStringFromSelector(_cmd)];
}

#pragma mark - repo url
- (void)setRepo_url:(NSString *)repo_url {
    [self setMunkiDomainObject:repo_url forKey:NSStringFromSelector(@selector(repo_url))];

}

- (NSString *)repo_url {
    return [self munkiimporterDomainObject:NSStringFromSelector(_cmd)];
}

# pragma mark - CFPrefs
- (id)munkiimporterDomainObject:(NSString *)key {
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)(key),
                                                           (__bridge CFStringRef)(kLGMunkiimportDomain)));
    return value;

}

- (void)setMunkiDomainObject:(id)object forKey:(NSString *)key {
    CFPreferencesSetAppValue((__bridge CFStringRef)(key),
                             (__bridge CFTypeRef)(object),
                             (__bridge CFStringRef)(kLGMunkiimportDomain));

}

@end
