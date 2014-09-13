//
//  LGDefaults.m
//  AutoPkgr
//
//  Created by Eldon on 8/5/14.
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

#import "LGDefaults.h"
#import "LGConstants.h"
#import "LGError.h"

@interface LGDefaults ()
// Make these readwrite here so we can use these with methods
@property (copy, nonatomic, readwrite) NSArray *autoPkgRecipeSearchDirs;
@property (copy, nonatomic, readwrite) NSDictionary *autoPkgRecipeRepos;
@end

@implementation LGDefaults

+ (LGDefaults *)standardUserDefaults
{
    static dispatch_once_t onceToken;
    static LGDefaults *shared;
    dispatch_once(&onceToken, ^{
        shared = [[LGDefaults alloc] init];
    });
    return shared;
}

- (BOOL)synchronize
{
    BOOL RC = [super synchronize] && CFPreferencesAppSynchronize((__bridge CFStringRef)(kLGAutoPkgPreferenceDomain));
    return RC;
}

#pragma mark
#pragma mark Email
- (NSString *)SMTPServer
{
    return [self objectForKey:kLGSMTPServer];
}

- (void)setSMTPServer:(NSString *)SMTPServer
{
    [self setObject:SMTPServer forKey:kLGSMTPServer];
}
#pragma mark
- (NSInteger)SMTPPort
{
    return [self integerForKey:kLGSMTPPort];
}

- (void)setSMTPPort:(NSInteger)SMTPPort
{
    [self setInteger:SMTPPort forKey:kLGSMTPPort];
}
#pragma mark
- (NSString *)SMTPUsername
{
    return [self objectForKey:kLGSMTPUsername];
}

- (void)setSMTPUsername:(NSString *)SMTPUsername
{
    [self setObject:SMTPUsername forKey:kLGSMTPUsername];
}
#pragma mark
- (NSString *)SMTPFrom
{
    return [self objectForKey:kLGSMTPFrom];
}

- (void)setSMTPFrom:(NSString *)SMTPFrom
{
    [self setObject:SMTPFrom forKey:kLGSMTPFrom];
}
#pragma mark
- (NSArray *)SMTPTo
{
    return [self objectForKey:kLGSMTPTo];
}

- (void)setSMTPTo:(NSArray *)SMTPTo
{
    [self setObject:SMTPTo forKey:kLGSMTPTo];
}

#pragma mark - BOOL
- (BOOL)SMTPTLSEnabled
{
    return [self boolForKey:kLGSMTPTLSEnabled];
}

- (void)setSMTPTLSEnabled:(BOOL)SMTPTLSEnabled
{
    [self setBool:SMTPTLSEnabled forKey:kLGSMTPTLSEnabled];
}
#pragma mark
- (BOOL)SMTPAuthenticationEnabled
{
    return [self boolForKey:kLGSMTPAuthenticationEnabled];
}

- (void)setSMTPAuthenticationEnabled:(BOOL)SMTPAuthenticationEnabled
{
    [self setBool:SMTPAuthenticationEnabled forKey:kLGSMTPAuthenticationEnabled];
}
#pragma mark
- (BOOL)warnBeforeQuittingEnabled
{
    return [self boolForKey:kLGWarnBeforeQuittingEnabled];
}

- (void)setWarnBeforeQuittingEnabled:(BOOL)WarnBeforeQuittingEnabled
{
    [self setBool:WarnBeforeQuittingEnabled forKey:kLGWarnBeforeQuittingEnabled];
}
#pragma mark
- (BOOL)hasCompletedInitialSetup
{
    return [self boolForKey:kLGHasCompletedInitialSetup];
}

- (void)setHasCompletedInitialSetup:(BOOL)HasCompletedInitialSetup
{
    [self setBool:HasCompletedInitialSetup forKey:kLGHasCompletedInitialSetup];
}
#pragma mark
- (BOOL)sendEmailNotificationsWhenNewVersionsAreFoundEnabled
{
    return [self boolForKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
}

- (void)setSendEmailNotificationsWhenNewVersionsAreFoundEnabled:(BOOL)SendEmailNotificationsWhenNewVersionsAreFoundEnabled
{
    [self setBool:SendEmailNotificationsWhenNewVersionsAreFoundEnabled forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
}
#pragma mark
- (BOOL)checkForNewVersionsOfAppsAutomaticallyEnabled
{
    return [self boolForKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
}

- (void)setCheckForNewVersionsOfAppsAutomaticallyEnabled:(BOOL)CheckForNewVersionsOfAppsAutomaticallyEnabled
{
    [self setBool:CheckForNewVersionsOfAppsAutomaticallyEnabled forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
}
#pragma mark
- (BOOL)checkForRepoUpdatesAutomaticallyEnabled
{
    return [self boolForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
}

- (void)setCheckForRepoUpdatesAutomaticallyEnabled:(BOOL)checkForRepoUpdatesAutomaticallyEnabled
{
    [self setBool:checkForRepoUpdatesAutomaticallyEnabled forKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
}

#pragma mark - AutoPkg Defaults
- (NSInteger)autoPkgRunInterval
{
    return [self integerForKey:kLGAutoPkgRunInterval];
}

- (void)setAutoPkgRunInterval:(NSInteger)autoPkgRunInterval
{
    [self setInteger:autoPkgRunInterval forKey:kLGAutoPkgRunInterval];
}

#pragma mark
- (NSString *)autoPkgCacheDir
{
    return [self autoPkgDomainObject:@"CACHE_DIR"];
}

- (void)setAutoPkgCacheDir:(NSString *)autoPkgCacheDir
{
    [self setAutoPkgDomainObject:autoPkgCacheDir forKey:@"CACHE_DIR"];
}

#pragma mark
- (NSString *)autoPkgRecipeOverridesDir
{
    return [self autoPkgDomainObject:@"RECIPE_OVERRIDE_DIRS"];
}

- (void)setAutoPkgRecipeOverridesDir:(NSString *)autoPkgRecipeOverridesDir
{
    [self setAutoPkgDomainObject:autoPkgRecipeOverridesDir forKey:@"RECIPE_OVERRIDE_DIRS"];
}

#pragma mark
- (NSString *)autoPkgRecipeRepoDir
{
    return [self autoPkgDomainObject:@"RECIPE_REPO_DIR"];
}

- (void)setAutoPkgRecipeRepoDir:(NSString *)autoPkgRecipeRepoDir
{
    [self setAutoPkgDomainObject:autoPkgRecipeRepoDir forKey:@"RECIPE_REPO_DIR"];
}

#pragma mark
- (NSArray *)autoPkgRecipeSearchDirs
{
    return [self autoPkgDomainObject:@"RECIPE_SEARCH_DIRS"];
}

- (void)setAutoPkgRecipeSearchDirs:(NSArray *)autoPkgRecipeSearchDirs
{
    [self setAutoPkgDomainObject:autoPkgRecipeSearchDirs forKey:@"RECIPE_SEARCH_DIRS"];
}
#pragma mark
- (NSDictionary *)autoPkgRecipeRepos
{
    return [self autoPkgDomainObject:@"RECIPE_REPOS"];
}

- (void)setAutoPkgRecipeRepos:(NSDictionary *)autoPkgRecipeRepos
{
    [self setAutoPkgDomainObject:autoPkgRecipeRepos forKey:@"RECIPE_REPOS"];
}
#pragma mark
- (NSString *)munkiRepo
{
    return [self autoPkgDomainObject:@"MUNKI_REPO"];
}

- (void)setMunkiRepo:(NSString *)munkiRepo
{
    [self setAutoPkgDomainObject:munkiRepo forKey:@"MUNKI_REPO"];
}
#pragma mark
- (NSString *)gitPath
{
    return [self autoPkgDomainObject:@"GIT_PATH"];
}

- (void)setGitPath:(NSString *)gitPath
{
    [self setAutoPkgDomainObject:gitPath forKey:@"GIT_PATH"];
}
#pragma mark - Utility Settings
- (BOOL)debug
{
    return [self boolForKey:@"debug"];
}
- (void)setDebug:(BOOL)debug
{
    [self setBool:debug forKey:@"debug"];
}

#pragma mark - Util Methods
#pragma mark - CFPrefs
- (id)autoPkgDomainObject:(NSString *)key
{
    id value = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)(key),
                                                           (__bridge CFStringRef)(kLGAutoPkgPreferenceDomain)));
    return value;
}

- (void)setAutoPkgDomainObject:(id)object forKey:(NSString *)key
{
    CFPreferencesSetAppValue((__bridge CFStringRef)(key),
                             (__bridge CFTypeRef)(object),
                             (__bridge CFStringRef)(kLGAutoPkgPreferenceDomain));
}

#pragma mark - Class Methods
+ (BOOL)fixRelativePathsInAutoPkgDefaults:(NSError *__autoreleasing *)error neededFixing:(NSInteger *)neededFixing
{
    LGDefaults *defaults = [LGDefaults new];
    NSInteger pathRepaired = 0;
    NSInteger errorEncountered = 0;

    NSFileManager *manager = [NSFileManager new];
    // Check the RECIPE_REPO_DIR key
    if ([[defaults.autoPkgRecipeRepoDir pathComponents].firstObject isEqualToString:@"~"]) {
        defaults.autoPkgRecipeRepoDir = defaults.autoPkgRecipeRepoDir.stringByExpandingTildeInPath;
        pathRepaired++;
    }

    // Check the RECIPE_SEARCH_DIRS array
    // NSSet is used here so that only unique items are listed in the array.
    NSMutableSet *newRecipeSearchDirs = [NSMutableSet new];
    for (NSString *dir in defaults.autoPkgRecipeSearchDirs) {
        NSString *repairedDir;
        NSArray *splitDir = [dir componentsSeparatedByString:@"~"];
        // If we've got a count that's greater than 1 we found a ~
        if (splitDir.count > 1) {
            // Take the last item in the array and just append that to the home directory
            repairedDir = [NSHomeDirectory() stringByAppendingString:splitDir.lastObject];
        } else {
            repairedDir = dir;
        }
        BOOL isDir;
        // Check to make sure the new directory actually exists
        if ([manager fileExistsAtPath:dir isDirectory:&isDir] && isDir) {
            [newRecipeSearchDirs addObject:repairedDir];
            pathRepaired++;
        } else {
            errorEncountered = YES;
        }
    }
    defaults.autoPkgRecipeSearchDirs = [newRecipeSearchDirs allObjects];

    NSMutableDictionary *newRecipeRepos = [NSMutableDictionary new];
    for (NSString *key in defaults.autoPkgRecipeRepos.allKeys) {
        NSString *repairedKey;
        NSArray *splitKey = [key componentsSeparatedByString:@"~"];
        // If we've got a count that's greater than 1 we found a ~
        if (splitKey.count > 1) {
            // Take the last item in the array and just append that to the home directory
            repairedKey = [NSHomeDirectory() stringByAppendingString:splitKey.lastObject];
            if (![self moveRepoFrom:key to:repairedKey]) {
                // If a bad repo was found but could not be moved, do not add it to the list.
                repairedKey = nil;
                errorEncountered = YES;
            }
        } else {
            repairedKey = key;
        }
        BOOL isDir;
        if ([manager fileExistsAtPath:key isDirectory:&isDir] && isDir) {
            if (defaults.autoPkgRecipeRepos[key] && repairedKey) {
                [newRecipeRepos setObject:defaults.autoPkgRecipeRepos[key] forKey:repairedKey];
                pathRepaired++;
            }
        } else {
            errorEncountered = YES;
        }
    }
    defaults.autoPkgRecipeRepos = newRecipeRepos;
    [defaults synchronize];

    // Populate the pointers if needed
    if (neededFixing)
        *neededFixing = pathRepaired;
    if (errorEncountered) {
        return [LGError errorWithCode:kLGErrorReparingAutoPkgPrefs error:error];
    }
    return YES;
}

+ (BOOL)moveRepoFrom:(NSString *)fromPath to:(NSString *)toPath
{
    NSFileManager *manager = [NSFileManager new];
    // If the dest is a git repo everything is most likely fine
    if (![manager fileExistsAtPath:[toPath stringByAppendingPathComponent:@".git"]]) {
        // If the source is a git repo try and move it to the dest
        if ([manager fileExistsAtPath:[fromPath stringByAppendingPathComponent:@".git"]]) {
            // If the folder exists and looks like a recipe repo
            // try and remove it
            if ([manager fileExistsAtPath:toPath] &&
                [toPath rangeOfString:@"recipes"].location != NSNotFound) {
                NSLog(@"We found an item at %@ that needs to be removed.", toPath);
                [manager removeItemAtPath:toPath error:nil];
            } else {
                // There is something really wrong with the toPath, abort
                NSLog(@"Somthing is wrong with the RECIPE_REPO path: %@.", toPath);
                NSLog(@"The folder exists, but does not look like an actual recipe repo.");
                return NO;
            }
            NSLog(@"Copying repo from %@ to %@.", fromPath, toPath);

            return [manager moveItemAtPath:fromPath toPath:toPath error:nil];
        }
        // However if the source is not a git repo return NO so it won't get added to the repo list
        else {
            return NO;
        }
    }
    NSLog(@"Repo already exists at %@, no need to migrate.", toPath);
    return YES;
}

@end
