//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
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

#import "LGHostInfo.h"
#import "LGConstants.h"
#import "LGAutoPkgr.h"
#import "LGGitHubJSONLoader.h"
#import "LGVersionComparator.h"
#import "AHKeychain.h"

NSString *const kLGOfficialGit = @"/usr/local/git/bin";
NSString *const kLGCLIToolsGit = @"/Library/Developer/CommandLineTools/usr/bin";
NSString *const kLGXcodeGit = @"/Applications/Xcode.app/Contents/Developer/usr/bin";
NSString *const kLGHomeBrewGit = @"/usr/local/bin";
NSString *const kLGBoxenBrewGit = @"/opt/boxen/homebrew/bin";

@implementation LGHostInfo

+ (NSString *)getUserName
{
    return NSUserName();
}

+ (NSString *)getHostName
{
    return [[NSHost currentHost] name];
}

+ (NSString *)getUserAtHostName
{
    NSString *userAtHostName = [NSString stringWithFormat:@"%@@%@", [self getUserName], [self getHostName]];
    return userAtHostName;
}

+ (BOOL)gitInstalled
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    LGDefaults *defaults = [[LGDefaults alloc] init];
    NSString *foundGitPath;

    // First see if AutoPkg already has a GIT_PATH key set,
    // and if the executable still exists.
    BOOL success = NO;
    BOOL isDir;
    NSString *currentGit = [defaults gitPath];
    if ([fm fileExistsAtPath:currentGit isDirectory:&isDir] && !isDir) {
        if ([fm isExecutableFileAtPath:currentGit]) {
            foundGitPath = currentGit;
            success = YES;
        }
    } else {
        // If nothing is set, then iterate through the list
        // of known git paths trying to locate one.
        for (NSString *path in [self knownGitPaths]) {
            NSString *gitExec = [path stringByAppendingPathComponent:@"git"];
            if ([fm isExecutableFileAtPath:gitExec]) {
                // if we found a viable git binary write it into AutoPkg's preferences
                foundGitPath = gitExec;
                success = YES;
            }
        }
    }

    if ([foundGitPath isEqualToString:kLGOfficialGit]) {
        DLog(@"Using Official Git");
    } else if ([foundGitPath isEqualToString:kLGCLIToolsGit]) {
        DLog(@"Using Git installed via Xcode command line tools.");
    } else if ([foundGitPath isEqualToString:kLGXcodeGit]) {
        DLog(@"Using Git from Xcode Application.");
    } else if ([foundGitPath isEqualToString:kLGHomeBrewGit]) {
        DLog(@"Using Git from Homebrew.");
    } else if ([foundGitPath isEqualToString:kLGBoxenBrewGit]) {
        DLog(@"Using Git from boxen homebrew.");
    } else {
        DLog(@"Using Git binary at %@", foundGitPath);
    }

    defaults.gitPath = foundGitPath;
    return success;
}

+ (NSString *)getAutoPkgVersion
{
    NSTask *getAutoPkgVersionTask = [[NSTask alloc] init];
    NSPipe *getAutoPkgVersionPipe = [NSPipe pipe];
    NSFileHandle *fileHandle = [getAutoPkgVersionPipe fileHandleForReading];

    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"version", nil];

    [getAutoPkgVersionTask setLaunchPath:launchPath];
    [getAutoPkgVersionTask setArguments:args];
    [getAutoPkgVersionTask setStandardOutput:getAutoPkgVersionPipe];
    [getAutoPkgVersionTask setStandardError:getAutoPkgVersionPipe];

    [getAutoPkgVersionTask launch];
    [getAutoPkgVersionTask waitUntilExit];

    NSData *autoPkgVersionData = [fileHandle readDataToEndOfFile];
    NSString *autoPkgVersionString = [[NSString alloc] initWithData:autoPkgVersionData encoding:NSUTF8StringEncoding];

    return [autoPkgVersionString trimmed];
}

+ (NSString *)getJSSImporterVersion
{
    NSString *version;
    NSString *jssImporterInstallReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jssimporter.plist";
    NSString *jssAddonInstallReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jss-autopkg-addon.plist";

    if ([[NSFileManager defaultManager] fileExistsAtPath:jssImporterInstallReceipt]) {
        NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssImporterInstallReceipt];
        version = receiptDict[@"PackageVersion"];
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:jssAddonInstallReceipt]) {
        NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssAddonInstallReceipt];
        version = receiptDict[@"PackageVersion"];
    }

    return version;
}

+ (NSString *)getAppSupportDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    NSString *autoPkgrSupportDirectory = [applicationSupportDirectory stringByAppendingString:@"/AutoPkgr"];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    NSError *error;

    if ([fm fileExistsAtPath:autoPkgrSupportDirectory isDirectory:&isDir]) {
        if (!isDir) {
            [fm removeItemAtPath:autoPkgrSupportDirectory error:&error];
            if (error) {
                NSLog(@"%@ is a file, and it cannot be deleted.", autoPkgrSupportDirectory);
                return @"";
            }
            [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
            if (error) {
                NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
                return @"";
            }
        }
    } else {
        [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
        if (error) {
            NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
            return @"";
        }
    }

    return autoPkgrSupportDirectory;
}

+ (BOOL)autoPkgInstalled
{
    NSString *autoPkgPath = @"/usr/local/bin/autopkg";

    if ([[NSFileManager defaultManager] isExecutableFileAtPath:autoPkgPath]) {
        return YES;
    }

    return NO;
}

+ (BOOL)autoPkgUpdateAvailable
{
    // TODO: This check shouldn't block the main thread

    // Get the currently installed version of AutoPkg
    NSString *installedAutoPkgVersionString = [self getAutoPkgVersion];
    NSLog(@"Installed version of AutoPkg: %@", installedAutoPkgVersionString);

    // Get the latest version of AutoPkg available on GitHub
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];
    NSString *latestAutoPkgVersionString = [jsonLoader getLatestAutoPkgReleaseVersionNumber];

    // Determine if AutoPkg is up-to-date by comparing the version strings
    BOOL newVersionAvailable = [LGVersionComparator isVersion:latestAutoPkgVersionString greaterThanVersion:installedAutoPkgVersionString];
    if (newVersionAvailable) {
        NSLog(@"A new version of AutoPkg is available. Version %@ is installed and version %@ is available.", installedAutoPkgVersionString, latestAutoPkgVersionString);
        return YES;
    }
    return NO;
}

+ (BOOL)jssImporterInstalled
{
    NSString *jssAddonReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jss-autopkg-addon.plist";
    NSString *jssImporterReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jssimporter.plist";
    NSString *jssExec = @"/Library/AutoPkg/autopkglib/JSSImporter.py";

    BOOL check1 = [[NSFileManager defaultManager] fileExistsAtPath:jssAddonReceipt];
    BOOL check2 = [[NSFileManager defaultManager] fileExistsAtPath:jssImporterReceipt];
    BOOL check3 = [[NSFileManager defaultManager] fileExistsAtPath:jssExec];

    BOOL isInstalled = (check1 && check3) || (check2 && check3);

    return isInstalled;
}

+ (BOOL)jssImporterUpdateAvailable;
{
    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
    NSString *availableVersion = [loader latestVersion:kLGJSSImporterJSONURL];
    NSString *installedVersion = [self getJSSImporterVersion];
    BOOL updateAvailable = [LGVersionComparator isVersion:availableVersion
                                       greaterThanVersion:installedVersion];
    if (updateAvailable) {
        NSLog(@"Version %@ of JSSImporter is available. Version %@ is installed", availableVersion, installedVersion);
    }

    return updateAvailable;
}

+ (NSArray *)knownGitPaths
{
    return @[ kLGOfficialGit,
              kLGBoxenBrewGit,
              kLGHomeBrewGit,
              kLGXcodeGit,
              kLGCLIToolsGit,
    ];
}

+ (AHKeychain *)appKeychain
{
    NSString *appKeychain = @"AutoPkgr.keychain";

    BOOL success = YES;
    AHKeychain *keychain;

    NSString *fullPath = [NSString stringWithFormat:@"%@/Library/Keychains/%@", NSHomeDirectory(), appKeychain];
    NSString *password = [[self class] macSerialNumber];

    if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath]) {
        keychain = [[AHKeychain alloc] initCreatingNewKeychain:appKeychain password:password];
        if (!keychain) {
            success = NO;
        }
    } else {
        keychain = [[AHKeychain alloc] initWithKeychain:appKeychain];
        success = [keychain unlockWithPassword:password];
    }

    return success ? keychain : nil;
}

+ (NSString *)macSerialNumber
{
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    CFStringRef cfSerialNumber = NULL;
    NSString *serialNumber = nil;

    if (platformExpert) {
        cfSerialNumber = IORegistryEntryCreateCFProperty(platformExpert,
                                                         CFSTR(kIOPlatformSerialNumberKey),
                                                         kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }

    if (cfSerialNumber) {
        serialNumber = [NSString stringWithString:CFBridgingRelease(cfSerialNumber)];
    }

    return serialNumber;
}

@end
