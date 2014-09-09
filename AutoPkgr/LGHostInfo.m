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
    NSArray *knownGitPaths = [[self class] knownGitPaths];

    for (NSString *path in knownGitPaths) {
        if ([fm isExecutableFileAtPath:[path stringByAppendingPathComponent:@"git"]]) {
            if ([path isEqualToString:knownGitPaths[0]]) {
                DLog(@"Git was installed via Xcode command line tools.");
            } else {
                DLog(@"Found Git binary at %@", path);
            }
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

+ (NSArray *)knownGitPaths
{
    return @[ @"/Library/Developer/CommandLineTools/usr/bin/", @"/usr/local/bin/", @"/opt/boxen/homebrew/bin/" ];
}
@end
