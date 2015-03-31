//
//  LGTools.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 2/7/15.
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
//

#import "LGTools.h"
#import "LGAutoPkgr.h"
#import "LGVersionComparator.h"
#import "LGGitHubJSONLoader.h"
#import "LGHostInfo.h"
#import "NSImage+statusLight.h"

NSString *const kLGToolAutoPkg = @"AutoPkg";
NSString *const kLGToolGit = @"Git";
NSString *const kLGToolJSSImporter = @"JSSImporter";

NSString *const kLGOfficialGit = @"/usr/local/git/bin/git";
NSString *const kLGCLIToolsGit = @"/Library/Developer/CommandLineTools/usr/bin/git";
NSString *const kLGXcodeGit = @"/Applications/Xcode.app/Contents/Developer/usr/bin/git";
NSString *const kLGHomeBrewGit = @"/usr/local/bin/git";
NSString *const kLGBoxenBrewGit = @"/opt/boxen/homebrew/bin/git";

NSArray * knownGitPaths()
{
    return @[ kLGOfficialGit,
              kLGBoxenBrewGit,
              kLGHomeBrewGit,
              kLGXcodeGit,
              kLGCLIToolsGit,
              ];
}

@interface LGTool ()
@property (copy, nonatomic, readwrite) NSString *name;
@property (copy, nonatomic, readwrite) NSString *installedVersion;
@property (copy, nonatomic, readwrite) NSString *remoteVersion;
@property (assign, nonatomic, readwrite) LGToolInstallStatus status;
@end

@implementation LGTool

- (NSImage *)statusImage
{
    NSImage *stausImage = nil;
    switch (self.status) {
    case kLGToolNotInstalled:
        stausImage = [NSImage LGStatusNotInstalled];
        break;
    case kLGToolUpdateAvailable:
        stausImage = [NSImage LGStatusUpdateAvailable];
        break;
    case kLGToolUpToDate:
    default:
        stausImage = [NSImage LGStatusUpToDate];
        break;
    }
    return stausImage;
}

- (NSString *)statusString
{
    NSString *statusString = @"";
    switch (self.status) {
    case kLGToolNotInstalled:
        statusString = [NSString stringWithFormat:@"%@ not installed.", self.name];
        break;
    case kLGToolUpdateAvailable:
        statusString = [NSString stringWithFormat:@"%@ %@ update now available.", self.name, self.remoteVersion];
        break;
    case kLGToolUpToDate:
    default:
        statusString = [NSString stringWithFormat:@"%@ %@ installed.", self.name, self.installedVersion];
        break;
    }
    return statusString;
}

- (NSString *)installButtonTitle
{
    return [NSString stringWithFormat:@"%@ %@", (self.status == kLGToolUpdateAvailable) ? @"Update" : @"Install", self.name];
}

- (BOOL)needsInstall
{
    switch (self.status) {
    case kLGToolNotInstalled:
    case kLGToolUpdateAvailable:
        return YES;
    case kLGToolUpToDate:
    default:
        return NO;
    }
}

@end

@implementation LGToolStatus

- (void)allToolsStatus:(void (^)(NSArray *tools))complete
{
    [[NSOperationQueue new] addOperationWithBlock:^{
        LGTool *autoPkgTool = [self autoPkgTool];
        LGTool *gitTool = [self gitTool];
        LGTool *jssImporterTool = [self jssImporterTool];
        complete(@[autoPkgTool, gitTool, jssImporterTool]);
    }];
}

#pragma mark - AutoPkg
- (void)autoPkgStatus:(void (^)(LGTool *))status
{
    [[NSOperationQueue new] addOperationWithBlock:^{
        LGTool *tool = [self autoPkgTool];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            status(tool);
        }];
    }];
}

- (LGTool *)autoPkgTool
{
    LGTool *tool = [[LGTool alloc] init];
    tool.name = kLGToolAutoPkg;


    // Get installed version
    NSString *installedVersion;
    [[self class] autoPkgInstalled:&installedVersion];

    // Get the latest version of AutoPkg available on GitHub
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];
    NSString *remoteVersion = [jsonLoader latestVersion:kLGAutoPkgReleasesJSONURL];

    tool.installedVersion = installedVersion;
    tool.remoteVersion = remoteVersion;
    tool.status = kLGToolUpToDate;

    if (!installedVersion || installedVersion.length == 0) {
        tool.status = kLGToolNotInstalled;
    } else if (installedVersion && remoteVersion) {
        if ([LGVersionComparator isVersion:remoteVersion greaterThanVersion:installedVersion]){
            tool.status = kLGToolUpdateAvailable;
        }
    }
    return tool;
}

#pragma mark - Git
- (void)gitStatus:(void (^)(LGTool *))status
{
    [[NSOperationQueue new] addOperationWithBlock:^{
        LGTool *tool = [self gitTool];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            status(tool);
        }];
    }];
}

- (LGTool *)gitTool
{
    // Git
    LGTool *tool = [[LGTool alloc] init];
    tool.name = kLGToolGit;

    NSString *installedVersion, *remoteVersion;
    [[self class] gitInstalled:&installedVersion];

    if ([[[LGDefaults standardUserDefaults] gitPath] isEqualToString:kLGOfficialGit]) {
        LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
        remoteVersion = [loader latestVersion:kLGGitReleasesJSONURL];
    }

    tool.installedVersion = installedVersion;
    tool.remoteVersion = remoteVersion;
    tool.status = kLGToolUpToDate;

    if (!installedVersion) {
        tool.status = kLGToolNotInstalled;
    } else if (installedVersion && remoteVersion) {
        if ([LGVersionComparator isVersion:remoteVersion greaterThanVersion:installedVersion]) {
            tool.status = kLGToolUpdateAvailable;
        }
    }
    return tool;
}

#pragma mark - JSSImporter
- (void)jssImporterStatus:(void (^)(LGTool *))status
{
    [[NSOperationQueue new] addOperationWithBlock:^{
        LGTool *tool = [self jssImporterTool];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            status(tool);
        }];
    }];
}

- (LGTool *)jssImporterTool
{
    LGTool *tool = [[LGTool alloc] init];
    tool.name = kLGToolJSSImporter;

    // Get installed version
    NSString *installedVersion;
    [[self class] jssImporterInstalled:&installedVersion];

    // Get remote version
    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
    NSString *remoteVersion = [loader latestVersion:kLGJSSImporterJSONURL];

    tool.installedVersion = installedVersion;
    tool.remoteVersion = remoteVersion;
    tool.status = kLGToolUpToDate;

    if (!installedVersion) {
        tool.status = kLGToolNotInstalled;
    } else if (installedVersion && remoteVersion) {
        if ([LGVersionComparator isVersion:remoteVersion greaterThanVersion:installedVersion]) {
            tool.status = kLGToolUpdateAvailable;
        }
    }

    return tool;
}

#pragma mark - Class Methods
+ (BOOL)gitInstalled
{
    return [self gitInstalled:nil];
}

+ (BOOL)gitInstalled:(NSString *__autoreleasing *)version
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
        for (NSString *path in knownGitPaths()) {
            NSString *gitExec = path;
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

    if (version && foundGitPath) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = foundGitPath;
        task.arguments = @[ @"--version" ];
        task.standardOutput = [NSPipe pipe];

        [task launch];
        [task waitUntilExit];

        NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        if (data) {
            NSString *rawVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *cleanVersion = [[rawVersion stringByReplacingOccurrencesOfString:@"git version " withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            *version = [[cleanVersion componentsSeparatedByString:@" "] firstObject];
        }
    }

    defaults.gitPath = foundGitPath;
    return success;
}


+ (BOOL)autoPkgInstalled
{
    NSString *autoPkgPath = @"/usr/local/bin/autopkg";
    if ([[NSFileManager defaultManager] isExecutableFileAtPath:autoPkgPath]) {
        return YES;
    }
    return NO;
}

+ (BOOL)autoPkgInstalled:(NSString *__autoreleasing*)version
{
    if ([[self class] autoPkgInstalled]) {
        // Get the currently installed version of AutoPkg
        NSTask *task = [[NSTask alloc] init];

        task.launchPath = @"/usr/bin/python";
        task.arguments = @[@"/usr/local/bin/autopkg", @"version"];
        task.standardOutput = [NSPipe pipe];
        [task launch];
        [task waitUntilExit];

        NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        if (data && version) {
            *version = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] trimmed];
        }
        return YES;
    }
    return NO;
}

+ (BOOL)jssImporterInstalled
{
    return [[self class] jssImporterInstalled:nil];
}

+ (BOOL)jssImporterInstalled:(NSString *__autoreleasing*)version
{
    NSString *jssAddonReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jss-autopkg-addon.plist";
    NSString *jssImporterReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jssimporter.plist";

    NSString *jssExec = @"/Library/AutoPkg/autopkglib/JSSImporter.py";
    NSString *installedVersion;

    if ([[NSFileManager defaultManager] fileExistsAtPath:jssExec]) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:jssImporterReceipt]) {
            NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssImporterReceipt];
            installedVersion = receiptDict[@"PackageVersion"];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:jssAddonReceipt]) {
            NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssAddonReceipt];
            installedVersion = receiptDict[@"PackageVersion"];
        }
    }
    if (version) {
        *version = installedVersion;
    }
    return (installedVersion != nil);
}


@end
