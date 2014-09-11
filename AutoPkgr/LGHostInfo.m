//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

NSString *const kLGCLIToolsGit =  @"/Library/Developer/CommandLineTools/usr/bin" ;
NSString *const kLGXcodeGit = @"/Applications/Xcode.app/Contents/Developer/usr/bin/git";

@implementation LGHostInfo

- (NSString *)getUserName
{
    return NSUserName();
}

- (NSString *)getHostName
{
    return [[NSHost currentHost] name];
}

- (NSString *)getUserAtHostName
{
    NSString *userAtHostName = [NSString stringWithFormat:@"%@@%@", [self getUserName], [self getHostName]];

    return userAtHostName;
}

- (BOOL)gitInstalled
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    LGDefaults *defaults = [[LGDefaults alloc] init];
    
    // First see if AutoPkg already has a GIT_PATH key set
    // and if the executable still exists
    BOOL isDir;
    NSString *setGit = [defaults gitPath];
    if ([fm fileExistsAtPath:setGit isDirectory:&isDir] && !isDir) {
        if ([fm isExecutableFileAtPath:setGit]) {
            return YES;
        }
    }
    
    // If nothing is set, then iterate through the list
    // of known git paths trying to locate one.
    for (NSString *path in [self knownGitPaths]) {
        NSString *gitExec = [path stringByAppendingPathComponent:@"git"];
        if ([fm isExecutableFileAtPath:gitExec]) {
            if ([path isEqualToString:kLGCLIToolsGit]) {
                DLog(@"Using Git was installed via Xcode command line tools.");
            } else if ([path isEqualToString:kLGXcodeGit]){
                DLog(@"Using Git from XCode Applicaiton.");
            } else {
                DLog(@"Using Git binary at %@", gitExec);
            }
            
            // if we found a viable git binary write it into AutoPkg's preferences
            defaults.gitPath = gitExec;
            return YES;
        }
    }

    NSPredicate *gitInstallPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'GitOSX.Installer'"];
    NSArray *receipts = [fm contentsOfDirectoryAtPath:@"/var/db/receipts" error:nil];

    if ([receipts filteredArrayUsingPredicate:gitInstallPredicate].count) {
        DLog(@"Git was installed via the official Git installer.");
        return YES;
    }

    return NO;
}

- (NSString *)getAutoPkgVersion
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
    NSString *trimmedVersionString = [autoPkgVersionString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    return trimmedVersionString;
}

- (BOOL)autoPkgInstalled
{
    NSString *autoPkgPath = @"/usr/local/bin/autopkg";

    if ([[NSFileManager defaultManager] isExecutableFileAtPath:autoPkgPath]) {
        return YES;
    }

    return NO;
}

- (BOOL)autoPkgUpdateAvailable
{
    // TODO: This check shouldn't block the main thread
    
    // Get the currently installed version of AutoPkg
    NSString *installedAutoPkgVersionString = [self getAutoPkgVersion];
    NSLog(@"Installed version of AutoPkg: %@", installedAutoPkgVersionString);
    
    // Get the latest version of AutoPkg available on GitHub
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];
    NSString *latestAutoPkgVersionString = [jsonLoader getLatestAutoPkgReleaseVersionNumber];
    
    // Determine if AutoPkg is up-to-date by comparing the version strings
    LGVersionComparator *vc = [[LGVersionComparator alloc] init];
    BOOL newVersionAvailable = [vc isVersion:latestAutoPkgVersionString greaterThanVersion:installedAutoPkgVersionString];
    if (newVersionAvailable) {
        NSLog(@"A new version of AutoPkg is available. Version %@ is installed and version %@ is available.", installedAutoPkgVersionString, latestAutoPkgVersionString);
        return YES;
    }
    return NO;
}

- (NSArray *)knownGitPaths
{
    return @[ @"/usr/local/git/bin",
              @"/opt/boxen/homebrew/bin",
              @"/usr/local/bin",
              kLGCLIToolsGit,
              kLGXcodeGit];
}

@end
