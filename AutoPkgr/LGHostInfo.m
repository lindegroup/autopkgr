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

- (NSString *)getAutoPkgCacheDir
{
    NSString *autoPkgCacheFolderFromPrefs = (__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("CACHE_DIR"), CFSTR("com.github.autopkg"));

    if (!autoPkgCacheFolderFromPrefs) {
        NSString *autoPkgCacheFolder = [NSString stringWithFormat:@"%@/Library/AutoPkg/Cache", NSHomeDirectory()];
        NSLog(@"Unable to get CACHE_DIR from the com.github.autopkg preference domain. Using the default path of %@.", autoPkgCacheFolder);
        return autoPkgCacheFolder;
    }

    return autoPkgCacheFolderFromPrefs;
}

- (NSString *)getAutoPkgRecipeReposDir
{
    NSString *autoPkgRecipeReposFolderFromPrefs = (__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("RECIPE_REPO_DIR"), CFSTR("com.github.autopkg"));

    if (!autoPkgRecipeReposFolderFromPrefs) {
        NSString *autoPkgRecipeReposFolder = [NSString stringWithFormat:@"%@/Library/AutoPkg/RecipeRepos", NSHomeDirectory()];
        NSLog(@"Unable to get RECIPE_REPO_DIR from the com.github.autopkg preference domain. Using the default path of %@.", autoPkgRecipeReposFolder);
        return autoPkgRecipeReposFolder;
    }

    return autoPkgRecipeReposFolderFromPrefs;
}

- (NSString *)getMunkiRepoDir
{
    NSString *localMunkiRepoFolderFromPrefs = (__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("repo_path"), CFSTR("com.googlecode.munki.munkiimport"));

    if (!localMunkiRepoFolderFromPrefs) {
        NSString *localMunkiRepoFolder = @"/Users/Shared/munki_repo";
        NSLog(@"Unable to get repo_path from the com.googlecode.munki.munkiimport preference domain. Using the default path of %@.", localMunkiRepoFolder);
        return localMunkiRepoFolder;
    }

    return localMunkiRepoFolderFromPrefs;
}

- (BOOL)gitInstalled
{
    NSArray *knownGitPaths = [[NSArray alloc] initWithObjects:@"/usr/bin/git", @"/usr/local/bin/git", @"/opt/boxen/homebrew/bin/git", nil];

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
