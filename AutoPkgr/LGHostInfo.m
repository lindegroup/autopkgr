//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGHostInfo.h"
#import "LGConstants.h"

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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (![defaults objectForKey:kLocalMunkiRepoPath]) {
        NSLog(@"Unable to find local Munki repo path in user defaults.");
        NSString *localMunkiRepoFolderFromMunkiPrefs = (__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("repo_path"), CFSTR("com.googlecode.munki.munkiimport"));
        NSString *localMunkiRepoFolderFromAutoPkgPrefs = (__bridge_transfer NSString *)CFPreferencesCopyAppValue(CFSTR("MUNKI_REPO"), CFSTR("com.github.autopkg"));

        if (!localMunkiRepoFolderFromMunkiPrefs) {

            if (!localMunkiRepoFolderFromAutoPkgPrefs) {
                NSString *localMunkiRepoFolder = @"/Users/Shared/munki_repo";
                NSLog(@"Unable to get repo_path from the com.googlecode.munki.munkiimport preference domain or MUNKI_REPO from the com.github.autopkg preference domain. Using the default path of %@.", localMunkiRepoFolder);
                return localMunkiRepoFolder;
            }

            return localMunkiRepoFolderFromAutoPkgPrefs;
        }

        return localMunkiRepoFolderFromMunkiPrefs;
    }

    return [defaults objectForKey:kLocalMunkiRepoPath];
}

- (BOOL)executableInstalled:(NSString *)exe
{
    NSTask *exeCheckTask = [[NSTask alloc] init];
    NSPipe *exeCheckPipe = [NSPipe pipe];

    [exeCheckTask setLaunchPath:@"/usr/bin/which"];
    [exeCheckTask setArguments:[NSArray arrayWithObject:exe]];
    [exeCheckTask setStandardOutput:exeCheckPipe];
    [exeCheckTask setStandardError:exeCheckPipe];
    [exeCheckTask launch];
    [exeCheckTask waitUntilExit];

    int terminationStatus = [exeCheckTask terminationStatus];

    if (terminationStatus == 0) {
        NSLog(@"%@ is installed.", exe);
        return YES;
    } else {
        NSLog(@"Unable to find executable %@ with `which`. Exit status: %d", exe, terminationStatus);
        return NO;
    }
}

- (BOOL)gitInstalled
{
    if ([self executableInstalled:@"git"]) {
        return YES;
    } else if ([self executableInstalled:@"/usr/bin/git"]) {
        return YES;
    } else if ([self executableInstalled:@"/usr/local/bin/git"]) {
        return YES;
    } else if ([self executableInstalled:@"/opt/boxen/homebrew/bin/git"]) {
        return YES;
    }

    return NO;
}

- (BOOL)autoPkgInstalled
{
    if ([self executableInstalled:@"autopkg"]) {
        return YES;
    } else if ([self executableInstalled:@"/usr/local/bin/autopkg"]) {
        return YES;
    }

    return NO;
}

@end
