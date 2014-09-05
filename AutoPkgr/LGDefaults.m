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

@implementation LGDefaults {
    LGDefaults *_autoPkgDefaults;
}

+ (LGDefaults *)autoPkgDefaults
{
    static dispatch_once_t onceToken;
    static LGDefaults *shared;
    dispatch_once(&onceToken, ^{
        shared = [[LGDefaults alloc] initForAutoPkg];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _autoPkgDefaults = [[[self class] alloc] initForAutoPkg];
    }
    return self;
}

- (instancetype)initForAutoPkg
{
    return [super initWithSuiteName:kLGAutoPkgPreferenceDomain];
}

- (instancetype)initForMunki
{
    return [super initWithSuiteName:@"ManagedInstalls"];
}

- (BOOL)synchronize
{
    if ([super synchronize] && [self->_autoPkgDefaults synchronize]) {
        return YES;
    }
    return NO;
}

#pragma mark - EMail
//
- (NSString *)SMTPServer
{
    return [self objectForKey:kLGSMTPServer];
}
- (void)setSMTPServer:(NSString *)SMTPServer
{
    [self setObject:SMTPServer forKey:kLGSMTPServer];
}
//
- (NSInteger)SMTPPort
{
    return [self integerForKey:kLGSMTPPort];
}
- (void)setSMTPPort:(NSInteger)SMTPPort
{
    [self setInteger:SMTPPort forKey:kLGSMTPPort];
}
//
- (NSString *)SMTPUsername
{
    return [self objectForKey:kLGSMTPUsername];
}
- (void)setSMTPUsername:(NSString *)SMTPUsername
{
    [self setObject:SMTPUsername forKey:kLGSMTPUsername];
}
//
- (NSString *)SMTPFrom
{
    return [self objectForKey:kLGSMTPFrom];
}
- (void)setSMTPFrom:(NSString *)SMTPFrom
{
    [self setObject:SMTPFrom forKey:kLGSMTPFrom];
}
//
- (NSArray *)SMTPTo
{
    return [self objectForKey:kLGSMTPTo];
}
//
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
//
- (BOOL)SMTPAuthenticationEnabled
{
    return [self boolForKey:kLGSMTPAuthenticationEnabled];
}
- (void)setSMTPAuthenticationEnabled:(BOOL)SMTPAuthenticationEnabled
{
    [self setBool:SMTPAuthenticationEnabled forKey:kLGSMTPAuthenticationEnabled];
}
//
- (BOOL)warnBeforeQuittingEnabled
{
    return [self boolForKey:kLGWarnBeforeQuittingEnabled];
}
- (void)setWarnBeforeQuittingEnabled:(BOOL)WarnBeforeQuittingEnabled
{
    [self setBool:WarnBeforeQuittingEnabled forKey:kLGWarnBeforeQuittingEnabled];
}
//
- (BOOL)hasCompletedInitialSetup
{
    return [self boolForKey:kLGHasCompletedInitialSetup];
}
- (void)setHasCompletedInitialSetup:(BOOL)HasCompletedInitialSetup
{
    [self setBool:HasCompletedInitialSetup forKey:kLGHasCompletedInitialSetup];
}
//
- (BOOL)sendEmailNotificationsWhenNewVersionsAreFoundEnabled
{
    return [self boolForKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
}
- (void)setSendEmailNotificationsWhenNewVersionsAreFoundEnabled:(BOOL)SendEmailNotificationsWhenNewVersionsAreFoundEnabled
{
    [self setBool:SendEmailNotificationsWhenNewVersionsAreFoundEnabled forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
}
//
- (BOOL)checkForNewVersionsOfAppsAutomaticallyEnabled
{
    return [self boolForKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
}
- (void)setCheckForNewVersionsOfAppsAutomaticallyEnabled:(BOOL)CheckForNewVersionsOfAppsAutomaticallyEnabled
{
    [self setBool:CheckForNewVersionsOfAppsAutomaticallyEnabled forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
}
//
-(BOOL)checkForRepoUpdatesAutomaticallyEnabled
{
    return [self boolForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
}
-(void)setCheckForRepoUpdatesAutomaticallyEnabled:(BOOL)checkForRepoUpdatesAutomaticallyEnabled
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
//
- (NSString *)autoPkgCacheDir
{
    return [_autoPkgDefaults objectForKey:@"CACHE_DIR"];
}
- (void)setAutoPkgCacheDir:(NSString *)autoPkgCacheDir
{
    [_autoPkgDefaults setObject:autoPkgCacheDir forKey:@"CACHE_DIR"];
}
- (NSString *)autoPkgRecipeOverridesDir
{
    return [_autoPkgDefaults objectForKey:@"RECIPE_OVERRIDE_DIRS"];
}
- (void)setAutoPkgRecipeOverridesDir:(NSString *)autoPkgRecipeOverridesDir
{
    [_autoPkgDefaults setObject:autoPkgRecipeOverridesDir forKey:@"RECIPE_OVERRIDE_DIRS"];
}
//
- (NSString *)autoPkgRecipeRepoDir
{
    return [_autoPkgDefaults objectForKey:@"RECIPE_REPO_DIR"];
}
- (void)setAutoPkgRecipeRepoDir:(NSString *)autoPkgRecipeRepoDir
{
    [_autoPkgDefaults setObject:autoPkgRecipeRepoDir forKey:@"RECIPE_REPO_DIR"];
}
//
- (NSArray *)autoPkgRecipeSearchDirs
{
    return [_autoPkgDefaults objectForKey:@"RECIPE_SEARCH_DIRS"];
}

- (void)setAutoPkgRecipeSearchDirs:(NSArray *)autoPkgRecipeSearchDirs
{
    [_autoPkgDefaults setObject:autoPkgRecipeSearchDirs forKey:@"RECIPE_SEARCH_DIRS"];
}
//
- (NSDictionary *)autoPkgRecipeRepos
{
    return [_autoPkgDefaults objectForKey:@"RECIPE_REPOS"];
}
- (void)setAutoPkgRecipeRepos:(NSDictionary *)autoPkgRecipeRepos
{
    [_autoPkgDefaults setObject:autoPkgRecipeRepos forKey:@"RECIPE_REPOS"];
}
//
- (NSString *)munkiRepo
{
    return [_autoPkgDefaults objectForKey:@"MUNKI_REPO"];
}
- (void)setMunkiRepo:(NSString *)munkiRepo
{
    [_autoPkgDefaults setObject:munkiRepo forKey:@"MUNKI_REPO"];
}
//

#pragma Class Methods
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
