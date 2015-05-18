// LGAutoPkgRecipe.m
//
// Copyright 2015 The Linde Group, Inc.
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

#import "LGAutoPkgRecipe.h"
#import "LGAutoPkgTask.h"

static NSString *const kLGMakeCatalogsIdentifier = @"com.github.autopkg.munki.makecatalogs";

@implementation LGAutoPkgRecipe {
@private
    /* This is the actual iVar used for the `enabled` property
     * which when initialize is -1. We then check for that value
     * during the -enabled getter and know if we need to do a more 
     * expensive check that initializes an array*/
    OSStatus _enabledInitialized;
}

@synthesize Description = _Description, MinimumVersion = _MinimumVersion, parentPlist = _parentPlist;

- (NSString *)description
{
    return [NSString stringWithFormat:@"Name: %@ Identifier: %@ Parent: %@", _Name, _Identifier, self.ParentRecipe];
}

- (instancetype)initWithRecipeFile:(NSURL *)recipeFile isOverride:(BOOL)isOverride
{
    if (self = [super init]) {
        if ((_recipePlist = [NSDictionary dictionaryWithContentsOfURL:recipeFile]) == nil) {
            return nil;
        }

        _Name = [[recipeFile lastPathComponent] stringByDeletingPathExtension];

        // There are two ways the identifiers are commonly refered to.
        _Identifier = _recipePlist[kLGAutoPkgRecipeIdentifierKey] ?: _recipePlist[@"Input"][@"IDENTIFIER"];

        _FilePath = recipeFile.path;
        _isOverride = isOverride;
        _enabledInitialized = -1;
    }
    return self;
}

- (NSString *)Description
{
    if (!_Description) {
        if(!(_Description = _recipePlist[NSStringFromSelector(_cmd)])){
            // try to get the parent recipe...
            _Description = self.parentPlist[NSStringFromSelector(_cmd)];
        }
    }
    return _Description;
}

- (NSString *)MinimumVersion
{
    if (!_MinimumVersion) {
        if (!( _MinimumVersion =_recipePlist[NSStringFromSelector(_cmd)])) {
            return self.parentPlist[NSStringFromSelector(_cmd)];
        }
    }
    return _MinimumVersion;
}

- (NSString *)ParentRecipe
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

- (NSArray *)ParentRecipes
{
    NSMutableArray *parents;
    if (self.ParentRecipe) {
        // Don't back this up with an iVar since when new recipe repos are
        // added this could actually trace the origin further back.

        NSArray *allRecipes = [[self class] allRecipesFilteringOverlaps:NO];
        LGAutoPkgRecipe *recipe = self;

        while (true) {
            if (recipe.ParentRecipe) {
                if (parents == nil) {
                    parents = [[NSMutableArray alloc] init];
                }

                NSPredicate *parentPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kLGAutoPkgRecipeIdentifierKey, recipe.ParentRecipe];

                recipe = [[allRecipes filteredArrayUsingPredicate:parentPredicate] firstObject];

                if (recipe.Identifier) {
                    [parents addObject:recipe.Identifier];
                }
            } else {
                break;
            }
        }
    }
    return [parents copy];
}

- (BOOL)isMissingParent
{
    if (self.ParentRecipe) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", kLGAutoPkgRecipeIdentifierKey, self.ParentRecipe];
        return [[[self class] allRecipesFilteringOverlaps:NO] filteredArrayUsingPredicate:predicate].count == 0;
    }
    return NO;
}

- (NSDictionary *)Input
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

- (NSArray *)Process
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

- (NSDictionary *)parentPlist {
    if (!_parentPlist) {
        NSMutableArray *recipes = [[NSMutableArray alloc] init];
        NSArray *searchDirs = [LGDefaults standardUserDefaults].autoPkgRecipeSearchDirs;
        for (NSString *searchDir in searchDirs) {
            if (![searchDir isEqualToString:@"."]) {
                [recipes addObjectsFromArray:[[self class] findRecipesRecursivelyAtPath:searchDir isOverride:NO]];
            }
        }
        [recipes enumerateObjectsUsingBlock:^(LGAutoPkgRecipe *recipe, NSUInteger idx, BOOL *stop) {
            if ([recipe.Identifier isEqualToString:self.ParentRecipe]) {
                _parentPlist = recipe.recipePlist;
                *stop = YES;
            }
        }];
    }
    return _parentPlist;
};

#pragma mark - Enabled
- (BOOL)isEnabled
{
    if (_enabledInitialized == -1) {
        _enabledInitialized = [[[self class] activeRecipes] containsObject:self.Identifier];
    }
    return _enabledInitialized;
}

- (void)setEnabled:(BOOL)enabled
{
    if ([self.Identifier isEqualToString:kLGMakeCatalogsIdentifier]) {
        return;
    }

    NSError *error;

    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if (!autoPkgrSupportDirectory.length) {
        NSLog(@"Could not write recipe_list.txt.");
        return;
    }

    NSString *recipeListFile = [[self class] defaultRecipeList];
    NSString *fileContents = [NSString stringWithContentsOfFile:recipeListFile encoding:NSUTF8StringEncoding error:nil];

    __block NSMutableArray *currentList = [[[fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] removeEmptyStrings] mutableCopy];

    [currentList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isEqualToString:kLGMakeCatalogsIdentifier]) {
            [currentList removeObject:obj];
        }
    }];

    if (enabled) {
        if (![currentList containsObject:self.Identifier]) {
            [currentList insertObject:self.Identifier atIndex:0];
        }
    } else {
        [currentList removeObject:self.Identifier];
    }

    // Iterate over the list to see if there are any .munki recipes to consider
    // If so re-add the makecatalogs recipe.
    [currentList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj rangeOfString:@"munki"].location != NSNotFound ) {
            [currentList addObject:kLGMakeCatalogsIdentifier];
            *stop = YES;
        }
    }];

    NSString *recipe_list = [currentList componentsJoinedByString:@"\n"];
    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error while writing %@.", recipeListFile);
        return;
    }

    currentList = nil;
    _enabledInitialized = enabled;
}

#pragma mark - Class Methods;
+ (NSArray *)allRecipes
{
    return [[self class] allRecipesFilteringOverlaps:YES];
}

+ (NSArray *)allRecipesFilteringOverlaps:(BOOL)filterOverlaps
{

    LGDefaults *defaults = [LGDefaults standardUserDefaults];
    NSMutableArray *allRecipes = [[NSMutableArray alloc] init];
    NSSet *activeRecipes = [self activeRecipes];

    NSArray *searchDirs = defaults.autoPkgRecipeSearchDirs;
    for (NSString *searchDir in searchDirs) {
        if (![searchDir isEqualToString:@"."]) {
            NSArray *recipes = [self findRecipesRecursivelyAtPath:searchDir.stringByExpandingTildeInPath isOverride:NO];
            [allRecipes addObjectsFromArray:recipes];
        }
    }

    // Iterate over the now completed list to update some keys
    for (LGAutoPkgRecipe *recipe in allRecipes) {
        /* mark whether they're enabled.
         * Use the _enabledInitialized iVar here since we don't actually
         * want to write to the recipe_list.txt file which is what the acessor does,
         * we just want to apply what is already in there. */
        if ([activeRecipes containsObject:recipe.Identifier]) {
            recipe->_enabledInitialized = YES;
        } else {
            recipe->_enabledInitialized = NO;
        }
    }

    NSString *recipeOverride = defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

    NSArray *overrideArray = [self findRecipesRecursivelyAtPath:recipeOverride isOverride:YES];

    NSMutableArray *validOverrides = [[NSMutableArray alloc] init];
    for (LGAutoPkgRecipe *override in overrideArray) {
        // Only consider the recipe valid if the parent exists
        NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, override.ParentRecipe];

        if ([parentExistsPredicate evaluateWithObject:allRecipes]) {
            [validOverrides addObject:override];

            if ([activeRecipes containsObject:override.Identifier]) {
                override->_enabledInitialized = YES;
            } else {
                override->_enabledInitialized = NO;
            }
        }
    }

    if (filterOverlaps) {
        for (LGAutoPkgRecipe *override in validOverrides) {
            // Filter the array by removing the parent recipe if an override is
            // found that matches BOTH condition: the value for the "Name" key of the the
            // override is same as the vlaue for the "Name" key of the Parent AND the value for
            // the Parent Recipe's Identifier key is the same as the value for override's "ParentRecipe" key
            NSPredicate *overridePreferedPredicate = [NSPredicate predicateWithFormat:@"not (%K == %@ AND %K == %@)", kLGAutoPkgRecipeNameKey, override.Name, kLGAutoPkgRecipeIdentifierKey, override.ParentRecipe];

            [allRecipes filterUsingPredicate:overridePreferedPredicate];
        }
    }

    // Now add the valid overrides into the recipeArray
    [allRecipes addObjectsFromArray:validOverrides];

    // Make a sorted array using the recipe Name as the sort key.
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kLGAutoPkgRecipeNameKey
                                                               ascending:YES];

    [allRecipes sortUsingDescriptors:@[ descriptor ]];

    return allRecipes.count ? allRecipes : nil;
}

+ (NSArray *)findRecipesRecursivelyAtPath:(NSString *)path isOverride:(BOOL)isOverride
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSMutableArray *array = [[NSMutableArray alloc] init];

    NSDirectoryEnumerator *enumerator;
    NSURL *searchDirURL = [NSURL fileURLWithPath:path.stringByExpandingTildeInPath];

    if (searchDirURL && [manager fileExistsAtPath:path]) {
        enumerator = [manager enumeratorAtURL:searchDirURL
                   includingPropertiesForKeys:@[ NSURLNameKey, NSURLIsDirectoryKey ]
                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                 errorHandler:^BOOL(NSURL *url, NSError *error) {
                                     return YES;
                                 }];

        NSURL *fileURL;
        for (fileURL in enumerator) {
            // As of autopkg 0.4.1 it only will find recipes
            // 2 levels deep so mimic that behavior here.
            if (enumerator.level <= 2) {
                NSString *filename;
                [fileURL getResourceValue:&filename forKey:NSURLNameKey error:nil];

                NSNumber *isDirectory;
                [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

                if (![isDirectory boolValue]) {
                    if ([filename.pathExtension isEqualToString:@"recipe"]) {
                        LGAutoPkgRecipe *recipe = [[LGAutoPkgRecipe alloc] initWithRecipeFile:fileURL isOverride:isOverride];
                        if (recipe) {
                            [array addObject:recipe];
                        }
                    }
                }
            }
        }
    }

    return [array copy];
}

+ (NSSet *)activeRecipes
{
    NSError *error;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableOrderedSet *activeRecipes = [[NSMutableOrderedSet alloc] init];
    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if (autoPkgrSupportDirectory.length) {
        NSString *autoPkgrRecipeListPath = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
        if ([fm fileExistsAtPath:autoPkgrRecipeListPath]) {
            NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:autoPkgrRecipeListPath encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                NSLog(@"Error reading %@.", autoPkgrRecipeList);
            } else {
                [activeRecipes addObjectsFromArray:[autoPkgrRecipeList componentsSeparatedByString:@"\n"]];
            }
        }
    }

    return [activeRecipes copy];
}

+ (NSString *)defaultRecipeList {
    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if (autoPkgrSupportDirectory.length) {
        return [autoPkgrSupportDirectory stringByAppendingPathComponent:@"recipe_list.txt"];
    }
    return nil;
}

+ (void)removeRecipeFromRecipeList:(NSString *)recipe
{
    NSError *error;
    NSMutableOrderedSet *recipes = [[LGAutoPkgRecipe activeRecipes] mutableCopy];
    [recipes removeObject:recipe];

    NSString *recipe_list = [recipes.array componentsJoinedByString:@"\n"];
    if(![recipe_list writeToFile:[self defaultRecipeList] atomically:YES encoding:NSUTF8StringEncoding error:&error]){
        NSLog(@"%@", error);
    }
}

+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error
{
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSString *orig = [[self class] defaultRecipeList];

        LGDefaults *defaults = [LGDefaults new];
        BOOL check1 = [defaults boolForKey:@"MigratedToIdentifiers"];
    
        BOOL check2 = [manager fileExistsAtPath:orig];
    
        if (check1 || !check2) {
            [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
            return YES;
        }
    
        NSLog(@"Prompting user to upgrade recipe list to new identifier format...");
    
        NSString *infoText = @"AutoPkgr now uses recipe identifiers instead of short names to specify recipes. This makes it possible to schedule and run identically-named recipes from separate repos.";
    
        NSAlert *alert = [NSAlert alertWithMessageText:@"AutoPkgr needs to convert your recipe list."
                                         defaultButton:@"Upgrade"
                                       alternateButton:@"Quit"
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", infoText];
    
        if ([alert runModal] == NSAlertDefaultReturn) {
    
            NSLog(@"Permission granted. Upgrading recipe list...");
            NSString *bak = [orig stringByAppendingPathExtension:@"v1.bak"];
            if ([manager fileExistsAtPath:orig] && ![manager fileExistsAtPath:bak]) {
                [manager copyItemAtPath:orig toPath:bak error:nil];
            }
    
            // Migrate Preferences
            __block int i = 0; // number of changed recipes
            NSArray *recipes = [self allRecipes];
            NSArray *activeRecipes = [[self activeRecipes] copy];

            [activeRecipes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                for (LGAutoPkgRecipe *recipe in recipes) {
                    if ([recipe.Name isEqualToString:obj]) {
                        recipe.enabled = YES;
                        i++;
                    }
                }
            }];



            BOOL success = (i == activeRecipes.count);
            [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
            // return NO if any were unable to be converted
            if (!success) {
                NSLog(@"An error may have occurred while converting the recipe list. We successfully converted %d out of %lu recipes. However it's also possible your recipe list was already converted. Please double check your enabled recipes now.", i, (unsigned long)activeRecipes.count);
            } else {
                NSLog(@"The recipe list was upgraded successfully.");
            }
            return YES;
        }
        NSLog(@"User chose not to upgrade recipe list.");
        return NO;
    
}
@end
