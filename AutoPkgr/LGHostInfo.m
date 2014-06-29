//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGHostInfo.h"

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
    NSArray *knownGitPaths = [[NSArray alloc] initWithObjects:@"/usr/bin/git", @"/usr/local/bin/git", @"/opt/boxen/homebrew/git", nil];

    for (NSString *path in knownGitPaths) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)autoPkgInstalled
{
    NSArray *knownAutoPkgPaths = [[NSArray alloc] initWithObjects:@"/usr/local/bin/autopkg", @"/usr/bin/autopkg", nil];

    for (NSString *path in knownAutoPkgPaths) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
            return YES;
        }
    }

    return NO;
}

@end
