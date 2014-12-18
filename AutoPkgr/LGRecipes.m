//
//  LGApplications.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/10/14.
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

#import "LGRecipes.h"
#import "LGAutoPkgr.h"
#import "LGRecipeOverrides.h"

@interface LGRecipes ()

@property (copy, nonatomic) NSArray *recipes;
@property (copy, nonatomic) NSMutableArray *activeRecipes;
@property (copy, nonatomic) NSArray *searchedRecipes;
@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;

@end

@implementation LGRecipes

- (id)init
{
    self = [super init];

    if (self) {
        _recipes = [[self getAllRecipes] removeEmptyStrings];
        _activeRecipes = [self getActiveRecipes];
        _searchedRecipes = _recipes;
    }

    return self;
}

- (void)awakeFromNib
{
    [self executeAppSearch:self];
    [_recipeSearchField setTarget:self];
    [_recipeSearchField setAction:@selector(executeAppSearch:)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCreateOverride:) name:kLGNotificationOverrideCreated object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDeleteOverride:) name:kLGNotificationOverrideDeleted object:nil];
}

- (void)reload
{
    _recipes = [[self getAllRecipes] removeEmptyStrings];
    [self executeAppSearch:self];
}

#pragma mark - Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRecipes count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"recipeCheckbox"]) {
        return @([_activeRecipes containsObject:[_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeIdentifierKey]]);
    } else {
        // For all other table columns, the identifiers are set to the key
        // for the cooresponding _searchRecipes dictionary entry, so we can just
        // use the column identifier to represent the appropriate value
        return [_searchedRecipes objectAtIndex:row][tableColumn.identifier];
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"recipeCheckbox"]) {
        NSDictionary *recipe = [_searchedRecipes objectAtIndex:row];
        if ([object isEqual:@YES]) {
            if (recipe[@"isMissingParentRecipe"]) {
                NSLog(@"Missing Parent Recipe %@", recipe[kLGAutoPkgRecipeParentKey]);
                [LGError presentErrorWithCode:kLGErrorMissingParentRecipe];
            } else {
                [_activeRecipes addObject:recipe[kLGAutoPkgRecipeIdentifierKey]];
            }
        } else {
            NSUInteger index = [_activeRecipes indexOfObject:recipe[kLGAutoPkgRecipeIdentifierKey]];
            if (index != NSNotFound) {
                [_activeRecipes removeObjectAtIndex:index];
            } else {
                NSLog(@"Cannot find item %@ in workingArray.", recipe[kLGAutoPkgRecipeNameKey]);
            }
        }
        [self writeRecipeList];
    }

    return;
}

#pragma mark - Filtering
- (NSMutableArray *)getActiveRecipes
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    NSMutableArray *activeRecipes = [[NSMutableArray alloc] init];
    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        return activeRecipes;
    }

    NSString *autoPkgrRecipeListPath = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    if ([fm fileExistsAtPath:autoPkgrRecipeListPath]) {
        NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:autoPkgrRecipeListPath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading %@.", autoPkgrRecipeList);
        } else {
            [activeRecipes addObjectsFromArray:[autoPkgrRecipeList componentsSeparatedByString:@"\n"]];
        }
    }
    return activeRecipes;
}

- (void)cleanActiveApps
{
    // This runs through the updated recipes and removes any recipes from the
    // activeApps array that cannot be found in the _recipes array.
    for (NSString *string in [_activeRecipes copy]) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@", kLGAutoPkgRecipeIdentifierKey, string];

        if (![_recipes filteredArrayUsingPredicate:predicate].count) {
            [_activeRecipes removeObject:string];
        }
    }
}

- (void)executeAppSearch:(id)sender
{
    [_recipeTableView beginUpdates];
    [_recipeTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    if ([[_recipeSearchField stringValue] isEqualToString:@""]) {
        _searchedRecipes = _recipes;
    } else {
        NSString *searchString = [_recipeSearchField stringValue];
        // Execute search both on Name and Identifier keys
        NSPredicate *recipeSearchPredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@ OR %K CONTAINS[CD] %@", kLGAutoPkgRecipeNameKey, searchString, kLGAutoPkgRecipeIdentifierKey, searchString];

        _searchedRecipes = [_recipes filteredArrayUsingPredicate:recipeSearchPredicate];
    }

    [_recipeTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    [_recipeTableView endUpdates];
}

#pragma mark - Recipe List
- (void)writeRecipeList
{
    [self cleanActiveApps];

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
    [_activeRecipes filterUsingPredicate:makeCatalogPredicate];
    // Check if any of the apps is a .munki run
    if ([_activeRecipes filteredArrayUsingPredicate:munkiPredicate].count) {
        // If so add MakeCatalogs.munki to the end of the list (so it runs last)
        [_activeRecipes addObject:makeCatalogsIdentifier];
    }

    NSString *recipe_list = [[_activeRecipes removeEmptyStrings] componentsJoinedByString:@"\n"];

    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error while writing %@.", recipeListFile);
    }
}

- (NSArray *)getAllRecipes
{
    LGDefaults *defaults = [LGDefaults standardUserDefaults];
    NSMutableArray *recipeArray = [[NSMutableArray alloc] init];

    NSArray *searchDirs = defaults.autoPkgRecipeSearchDirs;
    for (NSString *searchDir in searchDirs) {
        if (![searchDir isEqualToString:@"."]) {
            NSArray *recipes = [self findRecipesRecursivelyAtPath:searchDir.stringByExpandingTildeInPath isOverride:NO];
            [recipeArray addObjectsFromArray:recipes];
        }
    }

    for (NSMutableDictionary *recipe in recipeArray) {
        // Iterate over the now completed list and determine if parent recipes are missing
        NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, recipe[kLGAutoPkgRecipeParentKey]];

        if (recipe[kLGAutoPkgRecipeParentKey] && ![parentExistsPredicate evaluateWithObject:recipeArray]) {
            recipe[@"isMissingParentRecipe"] = @YES;
        }
    }

    NSString *recipeOverride = defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

    NSArray *overrideArray = [self findRecipesRecursivelyAtPath:recipeOverride isOverride:YES];

    NSMutableArray *validOverrides = [[NSMutableArray alloc] init];
    for (NSDictionary *override in overrideArray) {
        // Only consider the recipe valid if the parent exists
        NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, override[kLGAutoPkgRecipeParentKey]];

        if ([parentExistsPredicate evaluateWithObject:recipeArray]) {
            [validOverrides addObject:override];
        }
    }

    for (NSDictionary *override in validOverrides) {
        // Filter the array by removing the parent recipe if an override is
        // found that matches BOTH condition: the value for the "Name" key of the the
        // override is same as the vlaue for the "Name" key of the Parent AND the value for
        // the Parent Recipe's Identifier key is the same as the value for override's "ParentRecipe" key
        NSPredicate *overridePreferedPredicate = [NSPredicate predicateWithFormat:@"not (%K == %@ AND %K == %@)", kLGAutoPkgRecipeNameKey, override[kLGAutoPkgRecipeNameKey], kLGAutoPkgRecipeIdentifierKey, override[kLGAutoPkgRecipeParentKey]];
        [recipeArray filterUsingPredicate:overridePreferedPredicate];
    }

    // Now add the valid overrides into the recipeArray
    [recipeArray addObjectsFromArray:validOverrides];

    // Make a sorted array using the recipe Name as the sort key.
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kLGAutoPkgRecipeNameKey
                                                               ascending:YES];

    NSArray *sortedArray = [recipeArray sortedArrayUsingDescriptors:@[ descriptor ]];

    return sortedArray.count ? sortedArray : nil;
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


#pragma mark - Contextual Menu
- (NSMenu *)contextualMenuForRecipeAtRow:(NSInteger)row
{
    NSMenu *menu;

    NSDictionary *recipe = [_searchedRecipes objectAtIndex:row];

    if (recipe[@"isMissingParentRecipe"]){
        NSLog(@"Missing Parent Recipe");
    }

    menu = [[NSMenu alloc] init];
    NSMenuItem *item1;
    NSMenuItem *item2;
    NSMenuItem *item3;

    if (recipe[kLGAutoPkgRecipeParentKey]) {
        NSString *parent = [@"Parent Recipe: " stringByAppendingString:recipe[kLGAutoPkgRecipeParentKey]];
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
        if ([_activeRecipes containsObject:old]) {
            [_activeRecipes replaceObjectAtIndex: [_activeRecipes indexOfObject:old] withObject:new];
            changed = YES;
        }

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

+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *orig = [LGRecipes recipeList];
    LGDefaults *defaults = [LGDefaults new];
    BOOL check1 = [defaults boolForKey:@"MigratedToIdentifiers"];
    BOOL check2 = [manager fileExistsAtPath:orig];

    if (check1 || !check2){
        [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
        return YES;
    }

    NSString *infoText = @"As of version 1.2 AutoPkgr uses recipe Identifiers rather than short names to specify recipes, this makes it possible to schedule and run recipes from seperate repos that happen to have the same short name, such as Firefox.recipe.\n\nWe do our best to get this conversion right, but there's no guarentee, so double check what's enabled after this process.\n\nJust to be safe your current recipe_list.txt has been backed up as \"~/Library/Application Support/AutoPkgr/recipe_list.txt.v1.bak\".\n\nIf you choose to not continue you will need to roll back to an older v1.1.x version.";

    NSAlert *alert = [NSAlert alertWithMessageText:@"AutoPkgr v1.2 needs to migrate your current recipe list."
                                     defaultButton:@"Continue"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@"%@",infoText];

    if([alert runModal] == NSAlertDefaultReturn){

        NSString *bak = [orig stringByAppendingPathExtension:@"v1.bak"];
        if ([manager fileExistsAtPath:orig] && ![manager fileExistsAtPath:bak]) {
            [manager copyItemAtPath:orig toPath:bak error:nil];
        }

        // Migrate Preferences
        int i = 0; // number of changed recipes
        LGRecipes *recipes = [[LGRecipes alloc] init];
        if (recipes.activeRecipes.count) {
            for (NSString *recipe in [recipes.activeRecipes copy]){
                NSUInteger index = [recipes.recipes indexOfObjectPassingTest:
                                    ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                                        return [dict[@"Name"] isEqualToString:recipe];
                                    }];
                if (index != NSNotFound) {
                    NSInteger replaceIndex = [recipes.activeRecipes indexOfObjectIdenticalTo:recipe];
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
            NSLog(@"A possible error occured while converting the recipe list. We successfully converted %d out of %lu recipes. However it's also possible your recipe list was already converted. Please double check your enabled recipes.",i,(unsigned long)recipes.activeRecipes.count);

        }
        return  YES;
    }
    return NO;
}

@end
