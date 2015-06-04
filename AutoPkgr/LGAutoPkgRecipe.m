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
#import <glob.h>

// MakeCatalogs recipe identifier string
static NSString *const kLGMakeCatalogsIdentifier = @"com.github.autopkg.munki.makecatalogs";

// Dispatch queue for enabling / disabling recipe
static dispatch_queue_t autopkgr_recipe_write_queue()
{
    static dispatch_queue_t autopkgr_recipe_write_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        autopkgr_recipe_write_queue = dispatch_queue_create("com.lindegroup.autopkgr.recipe.write.queue", DISPATCH_QUEUE_SERIAL );
    });

    return autopkgr_recipe_write_queue;
}

static NSMutableDictionary *_identifierURLStore = nil;

#pragma mark - Recipes
//////////////////////////////////////////////////////////////////////////
// Recipes                                                             ///
//////////////////////////////////////////////////////////////////////////

@implementation LGAutoPkgRecipe {
@private
    /* This is the actual iVar used for the `enabled` property
     * which when initialize is -1. We then check for that value
     * during the -enabled getter and know if we need to do a more
     * expensive check that initializes an array */
    OSStatus _enabledInitialized;
    NSURL *_recipeFileURL;
}

@synthesize Description = _Description, MinimumVersion = _MinimumVersion;

- (NSString *)description
{
    return [NSString stringWithFormat:@"Name: %@ Identifier: %@ Parent: %@", _Name, _Identifier, self.ParentRecipe];
}

- (instancetype)initWithRecipeFile:(NSURL *)recipeFile isOverride:(BOOL)isOverride
{
    // Don't Initialize anything if we can't determine a recipe identifier.
    NSDictionary *reciptPlist = [NSDictionary dictionaryWithContentsOfURL:recipeFile];
    NSString *identifier = reciptPlist[kLGAutoPkgRecipeIdentifierKey] ?: reciptPlist[@"Input"][@"IDENTIFIER"];

    if (identifier && (self = [super init])) {
        _recipePlist = reciptPlist;
        _Identifier = identifier;

        _recipeFileURL = recipeFile;
        _Name = [[recipeFile lastPathComponent] stringByDeletingPathExtension];

        _FilePath = recipeFile.path;
        _isOverride = isOverride;
        _enabledInitialized = -1;

        [_identifierURLStore setObject:_recipeFileURL forKey:_Identifier];
    }
    return self;
}

- (NSString *)Description
{
    return _recipePlist[NSStringFromSelector(_cmd)] ?: [self objectForKey:NSStringFromSelector(_cmd) ofIdentifier:self.ParentRecipe];
}

- (NSString *)MinimumVersion
{
    return _recipePlist[NSStringFromSelector(_cmd)] ?: [self objectForKey:NSStringFromSelector(_cmd) ofIdentifier:self.ParentRecipe];
}

- (NSString *)ParentRecipe
{
    return _recipePlist[kLGAutoPkgRecipeParentKey];
}

- (NSArray *)ParentRecipes
{
    NSMutableArray *parents;
    NSString *parentRecipeID = self.ParentRecipe;

    if (parentRecipeID) {
        // Don't back this up with an iVar since when new recipe repos are
        // added this could actually trace the origin further back.
        parents = [NSMutableArray arrayWithObject:parentRecipeID];

        while (true) {
            NSURL *parentRecipeURL = [_identifierURLStore objectForKey:parentRecipeID];
            if (parentRecipeURL) {
                NSDictionary *recipePlist = [NSDictionary dictionaryWithContentsOfURL:parentRecipeURL];
                parentRecipeID = recipePlist[kLGAutoPkgRecipeParentKey];
                if (parentRecipeID) {
                    [parents addObject:parentRecipeID];
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
        return ([_identifierURLStore objectForKey:self.ParentRecipe] == nil);
    }
    return NO;
}

- (BOOL)recipeConfigError
{
    return self.isMissingParent;
}

- (NSDictionary *)Input
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

- (NSArray *)Process
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

#pragma mark - Enabled
- (void)enableRecipe:(NSButton *)sender
{
    if ([sender isKindOfClass:[NSButton class]]) {
        self.enabled = sender.state;
        // Double check that enabling of the recipe was successful.
        dispatch_async(autopkgr_recipe_write_queue(), ^{
            sender.state = [[[self class] activeRecipes] containsObject:self.Identifier];
        });
    }
}

- (BOOL)isEnabled
{
    if (_enabledInitialized == -1) {
        _enabledInitialized = [[[self class] activeRecipes] containsObject:self.Identifier];
    }
    return _enabledInitialized;
}

- (void)setEnabled:(BOOL)enabled
{
    /* We automatically handle the enabling of the makecatalogs recipe
     * so don't do anything if that's the one getting enabled. */
    if ([self.Identifier isEqualToString:kLGMakeCatalogsIdentifier]) {
        return;
    }

    /* This is all dispatched to a serial queue so a race condition doesn't arise
     * when multiple recipes are added or removed in rapid succession */
    dispatch_async(autopkgr_recipe_write_queue(), ^{
        NSError *error;

        /* Get the recipe list and split it by lines and turn it into an array */
        NSString *recipeListFile = [[self class] defaultRecipeList];
        NSString *fileContents = [NSString stringWithContentsOfFile:recipeListFile encoding:NSUTF8StringEncoding error:nil];
        __block NSMutableArray *currentList = [fileContents.split_byLine.removeEmptyStrings mutableCopy];

        /* Start by removing any instance of makecatalogs from the list, it's added back in later */
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

        /* Enumerate over the list to see if there are any .munki recipes
         * now listed. If so re-add the makecatalogs recipe. */
        [currentList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj rangeOfString:@"munki"].location != NSNotFound ) {
                [currentList addObject:kLGMakeCatalogsIdentifier];
                *stop = YES;
            }
        }];

        NSString *recipe_list = [currentList componentsJoinedByString:@"\n"];
        if (![recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"Error while writing %@.", recipeListFile);
            return;
        }

        currentList = nil;
        _enabledInitialized = enabled;
    });
}

#pragma mark - Checks
- (BOOL)hasStepProcessor:(NSString *)step
{
    NSMutableArray *considered = [NSMutableArray arrayWithObject:_recipePlist];

    for (NSString *identifier in self.ParentRecipes) {
        NSDictionary *plist = [self recipePlistForIdentifier:identifier];
        if (plist) {
            [considered addObject:plist];
        }
    }

    for (NSDictionary *plist in considered) {
        NSArray *processes = plist[kLGAutoPkgRecipeProcessKey];
        if (processes) {
            if ([processes indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
                return [obj[@"Processor"] isEqualToString:step];
                }] != NSNotFound) {
                return YES;
            }
        }
    };

    return NO;
}

- (BOOL)hasCheckPhase
{
    return [self hasStepProcessor:@"EndOfCheckPhase"];
}

- (BOOL)buildsPackage
{
    return [self hasStepProcessor:@"PkgCreator"];
}

#pragma mark - Value retrieval
- (NSDictionary *)recipePlistForIdentifier:(NSString *)identifier
{
    NSURL *recipeURL = [_identifierURLStore objectForKey:identifier];
    if (recipeURL) {
        return [NSDictionary dictionaryWithContentsOfURL:recipeURL];
    }
    return nil;
}

- (id)objectForKey:(NSString *)key ofIdentifier:(NSString *)identifier
{
    return [self recipePlistForIdentifier:identifier][key];
}

#pragma mark - Class Methods;
+ (NSArray *)allRecipes
{
    return [[self class] allRecipesFilteringOverlaps:YES];
}

+ (NSArray *)allRecipesFilteringOverlaps:(BOOL)filterOverlaps
{
    _identifierURLStore = [[NSMutableDictionary alloc] init];
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    NSMutableArray *allRecipes = [[NSMutableArray alloc] init];
    NSSet *activeRecipes = [self activeRecipes];

    NSArray *searchDirs = defaults.autoPkgRecipeSearchDirs;
    for (NSString *searchDir in searchDirs) {
        if (![searchDir isEqualToString:@"."]) {
            NSArray *recipeArray = [self findRecipesRecursivelyAtPath:searchDir.stringByExpandingTildeInPath isOverride:NO activeRecipes:activeRecipes];
            [allRecipes addObjectsFromArray:recipeArray];
        }
    }

    NSString *recipeOverridePath = defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

    NSArray *overrideArray = [self findRecipesRecursivelyAtPath:recipeOverridePath isOverride:YES activeRecipes:activeRecipes];
    NSMutableArray *validOverrides = [[NSMutableArray alloc] init];

    for (LGAutoPkgRecipe *override in overrideArray) {
        // Only consider the recipe valid if the parent exists
        NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, override.ParentRecipe];

        if ([parentExistsPredicate evaluateWithObject:allRecipes]) {
            [validOverrides addObject:override];
        }
    }

    if (filterOverlaps) {
        for (LGAutoPkgRecipe *override in validOverrides) {
            /* Filter the array by removing the parent recipe if an override is found that matches
             * BOTH conditions: the value for the "Name" key of the override is same as the value
             * for the "Name" key of the Parent AND the value for the Parent Recipe's "Identifier" key
             * is the same as the value for override's "ParentRecipe" key */
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

    validOverrides = nil;

    return allRecipes.count ? [allRecipes copy] : nil;
}

+ (NSArray *)findRecipesRecursivelyAtPath:(NSString *)path isOverride:(BOOL)isOverride activeRecipes:(NSSet *)activeRecipes
{
    NSMutableArray *recipes = [[NSMutableArray alloc] init];

    if (path && (access(path.UTF8String, F_OK) == 0)) {
        NSString *matches = [NSString stringWithFormat:@"{%@/{*.recipe,*/*.recipe}}", path];

        glob_t results;
        glob(matches.UTF8String, GLOB_BRACE | GLOB_NOSORT, NULL, &results);
        for (int i = 0; i < results.gl_matchc; i++) {
            NSURL *fileURL = [NSURL fileURLWithFileSystemRepresentation:results.gl_pathv[i] isDirectory:NO relativeToURL:nil];
            if (fileURL) {
                LGAutoPkgRecipe *recipe = [[LGAutoPkgRecipe alloc] initWithRecipeFile:fileURL isOverride:isOverride];
                if (recipe) {
                    [recipes addObject:recipe];
                    // If it's in the active recipe list, mark it as enabled.
                    if (activeRecipes) {
                        if ([activeRecipes containsObject:recipe.Identifier]) {
                            recipe->_enabledInitialized = YES;
                        } else {
                            recipe->_enabledInitialized = NO;
                        }
                    }
                }
            }
        }
        globfree(&results);
    }

    return [recipes copy];
}

+ (NSOrderedSet *)activeRecipes
{
    NSError *error;
    NSMutableOrderedSet *activeRecipes = [[NSMutableOrderedSet alloc] init];

    NSString *recipeList = [self defaultRecipeList];
    if (recipeList) {
        NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:recipeList encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading %@.", autoPkgrRecipeList);
        } else {
            [activeRecipes addObjectsFromArray:autoPkgrRecipeList.split_byLine];
        }
    }

    return [activeRecipes copy];
}

#pragma mark - Util
+ (NSString *)defaultRecipeList
{
    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if (autoPkgrSupportDirectory.length) {
        return [autoPkgrSupportDirectory stringByAppendingPathComponent:@"recipe_list.txt"];
    }
    return nil;
}

+ (BOOL)removeRecipeFromRecipeList:(NSString *)recipe
{
    NSError *error;
    NSMutableOrderedSet *recipes = [[LGAutoPkgRecipe activeRecipes] mutableCopy];
    [recipes removeObject:recipe];

    NSString *recipe_list = [recipes.array componentsJoinedByString:@"\n"];
    if (![recipe_list writeToFile:[self defaultRecipeList] atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSLog(@"%@", error);
        return NO;
    }
    return YES;
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
