// LGGitTool.m
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGGitTool.h"
#import "LGTool+Private.h"

#import "LGDefaults.h"

NSString *const kLGOfficialGit = @"/usr/local/git/bin/git";
NSString *const kLGCLIToolsGit = @"/Library/Developer/CommandLineTools/usr/bin/git";
NSString *const kLGXcodeGit = @"/Applications/Xcode.app/Contents/Developer/usr/bin/git";
NSString *const kLGHomeBrewGit = @"/usr/local/bin/git";
NSString *const kLGBoxenBrewGit = @"/opt/boxen/homebrew/bin/git";

NSArray *knownGitPaths()
{
    return @[ kLGOfficialGit,
              kLGBoxenBrewGit,
              kLGHomeBrewGit,
              kLGXcodeGit,
              kLGCLIToolsGit,
    ];
}

@implementation LGGitTool

@synthesize installedVersion = _installedVersion;
@synthesize remoteVersion = _remoteVersion;
@synthesize downloadURL = _downloadURL;

- (NSString *)name
{
    return @"Git";
}

- (LGToolTypeFlags)typeFlags
{
    return kLGToolTypeInstalledPackage;
}

- (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/timcharper/git_osx_installer/releases";
}

- (NSArray *)components
{
    return @[ [self binary],
    ];
}

- (NSString *)binary
{
    NSString *binary = nil;

    NSFileManager *fm = [[NSFileManager alloc] init];
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    // First see if AutoPkg already has a GIT_PATH key set,
    // and if the executable still exists.
    BOOL isDir;
    NSString *currentGit = [defaults gitPath];

    if ([fm fileExistsAtPath:currentGit isDirectory:&isDir] && !isDir) {
        if ([fm isExecutableFileAtPath:currentGit]) {
            binary = currentGit;
        }
    } else {
        // If nothing is set, then iterate through the list
        // of known git paths trying to locate one.
        for (NSString *path in knownGitPaths()) {
            NSString *gitExec = path;
            if ([fm isExecutableFileAtPath:gitExec]) {
                // if we found a viable git binary write it into AutoPkg's preferences
                binary = gitExec;
            }
        }
    }
    defaults.gitPath = binary;
    return binary;
}

- (NSString *)packageIdentifier
{
    return @"GitOSX.Installer.git221Universal.git.pkg";
}

- (NSString *)installedVersion
{
    NSString *rawVersion = [self versionTaskWithExec:self.binary
                                           arguments:@[ @"--version" ]];

    NSString *cleanVersion = [[rawVersion stringByReplacingOccurrencesOfString:@"git version " withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    _installedVersion = [[cleanVersion componentsSeparatedByString:@" "] firstObject];

    return _installedVersion;
}

- (NSString *)remoteVersion
{
    // Only return a remote version if currently using the official Git.
    if (!_remoteVersion && [self.binary isEqualToString:kLGOfficialGit]) {
        _remoteVersion = [super remoteVersion];
    }
    return _remoteVersion;
}

- (NSString *)downloadURL
{
    if (!_downloadURL) {
        BOOL OVER_10_8 = floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8;

        NSPredicate *match = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[CD] %@",
                                                              OVER_10_8 ? @"-mavericks.dmg" : @"-snow-leopard.dmg"];

        _downloadURL = [[self.gitHubInfo.latestReleaseDownloads filteredArrayUsingPredicate:match] firstObject];
#if DEBUG
        NSLog(@"Using download url for %@: %@", self.name, _downloadURL);
#endif
    }
    return _downloadURL;
}

@end
