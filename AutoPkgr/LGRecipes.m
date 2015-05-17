//
//  LGApplications.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/10/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGRecipes.h"
#import "LGAutoPkgr.h"
#import "LGRecipeOverrides.h"

@interface LGRecipes ()

@property (copy, nonatomic) NSMutableArray *recipes;
@property (copy, nonatomic) NSMutableArray *searchedRecipes;

@property (copy, nonatomic) NSMutableOrderedSet *activeRecipes;
@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;

@end

@implementation LGRecipes {
    LGAutoPkgTask *_runTask;
    NSString *_currentRunningRecipe;
}

static NSString *const kLGAutoPkgRecipeIsEnabledKey = @"isEnabled";
static NSString *const kLGAutoPkgRecipeMissingParentKey = @"isMissingParentRecipe";

- (void)awakeFromNib
{
    _activeRecipes = [[[self class] getActiveRecipes] mutableCopy];

    [self executeAppSearch:self];
    [_recipeSearchField setTarget:self];
    [_recipeSearchField setAction:@selector(executeAppSearch:)];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCreateOverride:) name:kLGNotificationOverrideCreated object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDeleteOverride:) name:kLGNotificationOverrideDeleted object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:kLGNotificationReposModified object:nil];
}

- (void)reload
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reload is used to rebuilt the index.
        // nil out _recipes here so when the self.recipes accessor is called
        // it will actually get reconstructed.
        _recipes = nil;
        [self executeAppSearch:self];
        [self writeRecipeList];
    });
}

#pragma mark - Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRecipes count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [_searchedRecipes objectAtIndex:row][tableColumn.identifier];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:kLGAutoPkgRecipeIsEnabledKey]) {
        NSMutableDictionary *recipe = [_searchedRecipes objectAtIndex:row];
        BOOL enable = [object boolValue];
        if (enable) {
            if (recipe[kLGAutoPkgRecipeMissingParentKey]) {
                NSLog(@"Missing parent recipe: %@", recipe[kLGAutoPkgRecipeParentKey]);
                [LGError presentErrorWithCode:kLGErrorMissingParentRecipe];
            } else {
                [_activeRecipes addObject:recipe[kLGAutoPkgRecipeIdentifierKey]];
                recipe[kLGAutoPkgRecipeIsEnabledKey] = @(enable);
            }
        } else {
            NSUInteger index = [_activeRecipes indexOfObject:recipe[kLGAutoPkgRecipeIdentifierKey]];
            if (index != NSNotFound) {
                [_activeRecipes removeObjectAtIndex:index];
                recipe[kLGAutoPkgRecipeIsEnabledKey] = @(enable);
            } else {
                NSLog(@"Cannot find item %@ in workingArray.", recipe[kLGAutoPkgRecipeNameKey]);
            }
        }

        [self writeRecipeList];
    }

    return;
}

-(void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    [_searchedRecipes sortUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

#pragma mark - Filtering
- (void)executeAppSearch:(id)sender
{
    [_recipeTableView beginUpdates];
    [_recipeTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    if (_recipeSearchField.stringValue.length == 0) {
        _searchedRecipes = self.recipes;
    } else {
        NSString *searchString = _recipeSearchField.stringValue;
        // Execute search both on Name and Identifier keys

        NSPredicate *recipeSearchPredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[CD] %@", kLGAutoPkgRecipeNameKey, searchString, kLGAutoPkgRecipeIdentifierKey, searchString];

        _searchedRecipes = [[self.recipes filteredArrayUsingPredicate:recipeSearchPredicate] mutableCopy];
    }

    [_recipeTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    [_recipeTableView endUpdates];
}


#pragma mark - Accessors
- (NSMutableArray *)recipes
{
    if (!_recipes) {
        LGDefaults *defaults = [LGDefaults standardUserDefaults];
        _recipes = [[NSMutableArray alloc] init];

        NSArray *searchDirs = defaults.autoPkgRecipeSearchDirs;
        for (NSString *searchDir in searchDirs) {
            if (![searchDir isEqualToString:@"."]) {
                NSArray *recipes = [self findRecipesRecursivelyAtPath:searchDir.stringByExpandingTildeInPath isOverride:NO];
                [_recipes addObjectsFromArray:recipes];
            }
        }

        // Iterate over the now completed list to update some keys
        for (NSMutableDictionary *recipe in _recipes) {
            // Determine if parent recipes are missing.
            NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, recipe[kLGAutoPkgRecipeParentKey]];

            if (recipe[kLGAutoPkgRecipeParentKey] && ![parentExistsPredicate evaluateWithObject:_recipes]) {
                recipe[kLGAutoPkgRecipeMissingParentKey] = @YES;
            }

            // mark whether they're enabled.
            if ([_activeRecipes containsObject:recipe[kLGAutoPkgRecipeIdentifierKey]]) {
                recipe[kLGAutoPkgRecipeIsEnabledKey] = @YES;
            } else {
                recipe[kLGAutoPkgRecipeIsEnabledKey] = @NO;
            }

            if (recipe[kLGAutoPkgRecipeParentKey]) {
                recipe[kLGAutoPkgRecipeParentKey] = [self parentsForRecipe:recipe];
            }
        }

        NSString *recipeOverride = defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

        NSArray *overrideArray = [self findRecipesRecursivelyAtPath:recipeOverride isOverride:YES];

        NSMutableArray *validOverrides = [[NSMutableArray alloc] init];
        for (NSMutableDictionary *override in overrideArray) {
            // Only consider the recipe valid if the parent exists
            NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, override[kLGAutoPkgRecipeParentKey]];

            if ([parentExistsPredicate evaluateWithObject:_recipes]) {
                [validOverrides addObject:override];

                // mark whether it's enabled.
                if ([_activeRecipes containsObject:override[kLGAutoPkgRecipeIdentifierKey]]) {
                    override[kLGAutoPkgRecipeIsEnabledKey] = @YES;
                } else {
                    override[kLGAutoPkgRecipeIsEnabledKey] = @NO;
                }
            }

            override[kLGAutoPkgRecipeParentKey] = [self parentsForRecipe:override];
        }

        for (NSMutableDictionary *override in validOverrides) {
            // Filter the array by removing the parent recipe if an override is
            // found that matches BOTH condition: the value for the "Name" key of the the
            // override is same as the vlaue for the "Name" key of the Parent AND the value for
            // the Parent Recipe's Identifier key is the same as the value for override's "ParentRecipe" key
            NSPredicate *overridePreferedPredicate = [NSPredicate predicateWithFormat:@"not (%K == %@ AND %K == %@)", kLGAutoPkgRecipeNameKey, override[kLGAutoPkgRecipeNameKey], kLGAutoPkgRecipeIdentifierKey, override[kLGAutoPkgRecipeParentKey]];

            [_recipes filterUsingPredicate:overridePreferedPredicate];

        }

        // Now add the valid overrides into the recipeArray
        [_recipes addObjectsFromArray:validOverrides];

        // Make a sorted array using the recipe Name as the sort key.
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kLGAutoPkgRecipeNameKey
                                                                   ascending:YES];
        
        [_recipes sortUsingDescriptors:@[ descriptor ]];
        
        return _recipes.count ? _recipes : nil;
    }

    return _recipes;
}

- (NSMutableOrderedSet *)activeRecipes {
    if (!_activeRecipes) {
        _activeRecipes = [[[self class] getActiveRecipes] mutableCopy];
    }
    return _activeRecipes;
}

#pragma mark - Recipe List
- (void)writeRecipeList
{
    // This runs through the updated recipes and removes any recipes from the
    // activeApps array that cannot be found in the _recipes array.
    [self.activeRecipes enumerateObjectsUsingBlock:^(NSString *string, NSUInteger idx, BOOL *stop) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", kLGAutoPkgRecipeIdentifierKey, string];

        if (![_recipes filteredArrayUsingPredicate:predicate].count) {
            [_activeRecipes removeObject:string];
        }
    }];


    [[self class] writeRecipeList:_activeRecipes];
}

- (NSArray *)findRecipesRecursivelyAtPath:(NSString *)path isOverride:(BOOL)isOverride
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
                        NSMutableDictionary *recipe = [self createRecipeDictFromURL:fileURL isOverride:isOverride];
                        if (recipe) {
                            [array addObject:recipe];
                        }
                    }
                }
            }
        }
    }
    return [NSArray arrayWithArray:array];
}

- (NSMutableDictionary *)createRecipeDictFromURL:(NSURL *)recipeURL isOverride:(BOOL)isOverride
{
    // Do some basic checks against the file url first.
    if (!recipeURL || !recipeURL.isFileURL) {
        return nil;
    }

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithContentsOfURL:recipeURL];
    // If we can't serialize the file, or there are not valid enteries then it's not a recipe
    if (dictionary.count) {
        NSString *recipeName = recipeURL.lastPathComponent.stringByDeletingPathExtension;
        [dictionary setObject:recipeName forKey:kLGAutoPkgRecipeNameKey];
        [dictionary setObject:@(isOverride) forKey:@"isOverride"];

        if (!dictionary[kLGAutoPkgRecipeIdentifierKey]) {
            if (dictionary[@"Input"][@"IDENTIFIER"]) {
                [dictionary setObject:dictionary[@"Input"][@"IDENTIFIER"] forKey:kLGAutoPkgRecipeIdentifierKey];
            }
        }
    }

    return dictionary.count ? dictionary : nil;
}

- (NSArray *)parentsForRecipe:(NSDictionary *)recipe {

    NSArray *results = nil;
    NSMutableArray *parents = [[NSMutableArray alloc] init];
    while (true) {
        if (recipe[kLGAutoPkgRecipeParentKey]) {
            NSPredicate *parentPredicate = [NSPredicate predicateWithFormat:@"%K == %@", kLGAutoPkgRecipeIdentifierKey, recipe[kLGAutoPkgRecipeParentKey]];

            results = [self.recipes filteredArrayUsingPredicate:parentPredicate];

            if (results.firstObject[kLGAutoPkgRecipeIdentifierKey]) {
                [parents addObject:results.firstObject[kLGAutoPkgRecipeIdentifierKey]];
            }
            recipe = results.firstObject;
        } else {
            break;
        }
    }

    return [parents copy];
}

#pragma mark- Run Task Menu Actions
- (void)cancelTask {
    if (_runTask) {
        [_runTask cancel];
    }
}

- (void)runRecipeFromMenu:(NSMenuItem *)item {

    _runTask = [LGAutoPkgTask runRecipesTask:@[item.representedObject]];
    _runTask.progressUpdateBlock = ^(NSString *message, double progress){
        NSLog(@"%@", message);
    };

    [_runTask launchInBackground:^(NSError *error) {
        if (error) {
            [[NSAlert alertWithError:error] runModal];
        }
    }];
}

#pragma mark - Contextual Menu
- (NSMenu *)contextualMenuForRecipeAtRow:(NSInteger)row
{
    NSMenu *menu;

    NSDictionary *recipe = [_searchedRecipes objectAtIndex:row];

    if (recipe[kLGAutoPkgRecipeMissingParentKey]) {
        NSLog(@"Missing parent recipe.");
    }

    menu = [[NSMenu alloc] init];

    if (!_runTask.isExecuting) {
        NSMenuItem *runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Run this recipe" action:@selector(runRecipeFromMenu:) keyEquivalent:@""];
        runMenuItem.target = self;
        runMenuItem.representedObject = recipe[kLGAutoPkgRecipeNameKey];
        [menu addItem:runMenuItem];
    } else {
        NSMenuItem *runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Cancel Run" action:@selector(cancel) keyEquivalent:@""];
        runMenuItem.target = _runTask;
        [menu addItem:runMenuItem];
    }

    // Setup other menu items...
    NSMenuItem *item1;
    NSMenuItem *item2;
    NSMenuItem *item3;

    if (recipe[kLGAutoPkgRecipeParentKey]) {
        NSString *parent = [@"Parent Recipe: " stringByAppendingString:[recipe[kLGAutoPkgRecipeParentKey] firstObject]];
        [menu addItemWithTitle:parent action:nil keyEquivalent:@""];
    }

    // Setup the recipe editor menu ...
    NSString *currentEditor = [[LGDefaults standardUserDefaults] objectForKey:@"RecipeEditor"];
    NSMenu *recipeEditorMenu = [[NSMenu alloc] init];
    NSMenuItem *recipeEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Set Recipe Editor" action:nil keyEquivalent:@""];

    for (NSString *editor in [LGRecipeOverrides recipeEditors]) {
        NSMenuItem *editorItem = [[NSMenuItem alloc] initWithTitle:editor action:@selector(setRecipeEditor:) keyEquivalent:@""];
        if ([editor isEqualToString:currentEditor]) {
            [editorItem setState:NSOnState];
        }
        editorItem.target = [LGRecipeOverrides class];
        [recipeEditorMenu addItem:editorItem];
    }

    NSMenuItem *otherEditorItem = [[NSMenuItem alloc] initWithTitle:@"Other..." action:@selector(setRecipeEditor:) keyEquivalent:@""];
    otherEditorItem.target = [LGRecipeOverrides class];

    [recipeEditorMenu addItem:otherEditorItem];

    if ([LGRecipeOverrides overrideExistsForRecipe:recipe]) {
        item1 = [[NSMenuItem alloc] initWithTitle:@"Open Recipe Override" action:@selector(openFile:) keyEquivalent:@""];
        item1.representedObject = recipe;

        // Reveal in finder menu item
        item2 = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
        item2.representedObject = recipe;
        item2.target = [LGRecipeOverrides class];

        // "Delete Override" menu item
        item3 = [[NSMenuItem alloc] initWithTitle:@"Remove Override" action:@selector(deleteOverride:) keyEquivalent:@""];
        item3.representedObject = recipe;

        item3.target = [LGRecipeOverrides class];

    } else {
        item1 = [[NSMenuItem alloc] initWithTitle:@"Create Override" action:@selector(createOverride:) keyEquivalent:@""];
        item1.representedObject = recipe;
    }

    item1.target = [LGRecipeOverrides class];

    if (item1) {
        [menu addItem:item1];
    }

    if (item2) {
        [menu addItem:item2];
    }

    if (item3) {
        [menu addItem:item3];
    }

    [menu addItem:recipeEditorMenuItem];
    [menu setSubmenu:recipeEditorMenu forItem:recipeEditorMenuItem];
    return menu;
}

#pragma mark - Notifications
- (void)didCreateOverride:(NSNotification *)aNotification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // The notification info of the didCreateOverride: note is a dictionary with two keys
        // "old" : dictionary of the recipe (it's parent) used to create the override
        // "new" : dictionary of the newly created override.
        NSDictionary *swap = aNotification.userInfo;
        NSString *old = swap[@"old"][kLGAutoPkgRecipeIdentifierKey];
        NSString *new = swap[@"new"][kLGAutoPkgRecipeIdentifierKey];
        BOOL changed = NO;

        // If the parent was active, and the override has the same name,
        // make the newly created override active
        [_activeRecipes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isEqualToString:old]) {
                [_activeRecipes replaceObjectAtIndex:idx withObject:new];
                *stop = YES;
            }
        }];


        [self reload];

        if (changed) {
            [self writeRecipeList];
        }
    }];
}

- (void)didDeleteOverride:(NSNotification *)aNotification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // The notification info of the didDeleteOverride: note is
        // the dictionary representation of the deleted override

        NSDictionary *override = aNotification.userInfo;
        NSString *name = override[kLGAutoPkgRecipeIdentifierKey];

        BOOL changed = NO;
        // Once the override is deleted, if it was in the _activeRecipes
        // list make sure to remove it there too.
        if (name && [_activeRecipes containsObject:name]) {
            [_activeRecipes removeObject:name];
            changed = YES;
        }

        [self reload];

        if (changed) {
            [self writeRecipeList];
        }
    }];
}

#pragma mark - Class Methods
+ (NSString *)recipeList
{
    NSString *applicationSupportDirectory = [LGHostInfo getAppSupportDirectory];
    return [applicationSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
}

+ (void)removeRecipeFromRecipeList:(NSString *)recipe
{
    NSMutableOrderedSet *recipes = [[[self class] getActiveRecipes] mutableCopy];
    [recipes removeObject:recipe];
    [[self class] writeRecipeList:recipes];
}

+ (void)writeRecipeList:(NSMutableOrderedSet *)recipes
{
    NSError *error;

    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        NSLog(@"Could not write recipe_list.txt.");
        return;
    }

    NSString *makeCatalogsIdentifier = @"com.github.autopkg.munki.makecatalogs";

    NSString *recipeListFile = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];

    NSPredicate *makeCatalogPredicate = [NSPredicate predicateWithFormat:@"not SELF contains[cd] %@", makeCatalogsIdentifier];

    NSPredicate *munkiPredicate = [NSPredicate predicateWithFormat:@"SELF contains[cd] 'munki'"];

    // Make a working array filtering out any instances of MakeCatalogs.munki, so there will only be one occurrence
    [recipes filterUsingPredicate:makeCatalogPredicate];
    // Check if any of the apps is a .munki run
    if ([recipes filteredOrderedSetUsingPredicate:munkiPredicate].count) {
        // If so add MakeCatalogs.munki to the end of the list (so it runs last)
        [recipes addObject:makeCatalogsIdentifier];
    }

    NSString *recipe_list = [[[recipes array] removeEmptyStrings] componentsJoinedByString:@"\n"];
    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error while writing %@.", recipeListFile);
    }
}

+ (NSSet *)getActiveRecipes
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

+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *orig = [LGRecipes recipeList];
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
        int i = 0; // number of changed recipes
        LGRecipes *recipes = [[LGRecipes alloc] init];
        if (recipes.activeRecipes.count) {
            for (NSString *recipe in [recipes.activeRecipes copy]) {
                NSUInteger index = [recipes.recipes indexOfObjectPassingTest:
                                                        ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                                        return [dict[@"Name"] isEqualToString:recipe];
                                                        }];
                if (index != NSNotFound) {

                    NSInteger replaceIndex = [recipes.activeRecipes indexOfObject:recipe]
;

                    [recipes.activeRecipes replaceObjectAtIndex:replaceIndex withObject:[recipes.recipes objectAtIndex:index][kLGAutoPkgRecipeIdentifierKey]];
                    i++;
                }
            }

            if (i > 0) {
                [recipes writeRecipeList];
            }
        }

        BOOL success = (i == recipes.activeRecipes.count);
        [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
        // return NO if any were unable to be converted
        if (!success) {
            NSLog(@"An error may have occurred while converting the recipe list. We successfully converted %d out of %lu recipes. However it's also possible your recipe list was already converted. Please double check your enabled recipes now.", i, (unsigned long)recipes.activeRecipes.count);
        } else {
            NSLog(@"The recipe list was upgraded successfully.");
        }
        return YES;
    }
    NSLog(@"User chose not to upgrade recipe list.");
    return NO;
}

@end
