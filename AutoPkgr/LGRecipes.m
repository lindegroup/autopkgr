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

@implementation LGRecipes

- (id)init
{
    self = [super init];

    if (self) {
        _activeRecipes = [self getActiveRecipes];
        _searchedRecipes = _recipes;
    }

    return self;
}

- (void)reload
{
    _recipes = [[LGAutoPkgTask listRecipes] removeEmptyStrings];
    [self executeAppSearch:self];
}

- (NSArray *)getActiveRecipes
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;

    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        return [[NSArray alloc] init];
    }

    NSString *autoPkgrRecipeListPath = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    if ([fm fileExistsAtPath:autoPkgrRecipeListPath]) {
        NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:autoPkgrRecipeListPath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading %@.", autoPkgrRecipeList);
            return [[NSArray alloc] init];
        }

        return [autoPkgrRecipeList componentsSeparatedByString:@"\n"];

    } else {
        return [[NSArray alloc] init];
    }

    return [[NSArray alloc] init];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRecipes count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"recipeCheckbox"]) {
        return @([_activeRecipes containsObject:[_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey]]);
    } else if ([[tableColumn identifier] isEqualToString:@"recipeName"]) {
        return [_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey];
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"recipeCheckbox"]) {
        NSMutableArray *workingArray = [NSMutableArray arrayWithArray:_activeRecipes];
        if ([object isEqual:@YES]) {
            [workingArray addObject:[_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey]];
        } else {
            NSUInteger index = [workingArray indexOfObject:[_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey]];
            if (index != NSNotFound) {
                [workingArray removeObjectAtIndex:index];
            } else {
                NSLog(@"Cannot find item %@ in workingArray.", [_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey]);
            }
        }
        _activeRecipes = [NSArray arrayWithArray:workingArray];
        [self writeRecipeList];
    }

    return;
}

- (void)cleanActiveApps
{
    // This runs through the updated recipes and removes any recipes from the
    // activeApps array that cannot be found in the new apps array.

    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:_activeRecipes];
    for (NSString *string in _activeRecipes) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == %@",kLGAutoPkgRecipeNameKey, string];

        if (![_recipes filteredArrayUsingPredicate:predicate]) {
            [workingArray removeObject:string];
        }
    }
    _activeRecipes = [NSArray arrayWithArray:workingArray];
}

- (void)writeRecipeList
{
    [self cleanActiveApps];

    NSError *error;

    NSString *autoPkgrSupportDirectory = [LGHostInfo getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        NSLog(@"Could not write recipe_list.txt.");
        return;
    }

    NSString *recipeListFile = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];

    NSPredicate *makeCatalogPredicate = [NSPredicate predicateWithFormat:@"not SELF contains[cd] 'MakeCatalogs.munki'"];
    NSPredicate *munkiPredicate = [NSPredicate predicateWithFormat:@"SELF contains[cd] 'munki'"];

    // Make a working array filtering out any instances of MakeCatalogs.munki, so there will only be one occurence
    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:[_activeRecipes filteredArrayUsingPredicate:makeCatalogPredicate]];

    // Check if any of the apps is a .munki run
    if ([workingArray filteredArrayUsingPredicate:munkiPredicate].count) {
        // If so add MakeCatalogs.munki to the end of the list (so it runs last)
        [workingArray addObject:@"MakeCatalogs.munki"];
    }

    NSString *recipe_list = [[workingArray removeEmptyStrings] componentsJoinedByString:@"\n"];

    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) {
        NSLog(@"Error while writing %@.", recipeListFile);
    }
}

- (void)executeAppSearch:(id)sender
{
    [_recipeTableView beginUpdates];
    [_recipeTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    if ([[_recipeSearchField stringValue] isEqualToString:@""]) {
        _searchedRecipes = _recipes;
    } else {
        NSPredicate *recipeSearchPred = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@",kLGAutoPkgRecipeNameKey,[_recipeSearchField stringValue]];
        _searchedRecipes = [_recipes filteredArrayUsingPredicate:recipeSearchPred];
    }

    [_recipeTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    [_recipeTableView endUpdates];
}

- (void)awakeFromNib
{
    [self reload];
    [_recipeSearchField setTarget:self];
    [_recipeSearchField setAction:@selector(executeAppSearch:)];
}

#pragma mark - Class Methods
+ (NSString *)recipeList
{
    NSString *applicationSupportDirectory = [LGHostInfo getAppSupportDirectory];
    return [applicationSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
}

- (NSMenu *)contextualMenuForRecipeAtRow:(NSInteger)row
{
    NSMenu *menu;

    NSString *recipe = [_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeNameKey];
    NSString *identifier = [_searchedRecipes objectAtIndex:row][kLGAutoPkgRecipeIdentifierKey];

    NSMenuItem *identifierItem = [[NSMenuItem alloc] initWithTitle:identifier action:nil keyEquivalent:@""];


    NSMenuItem *item;
    NSMenuItem *item2;

    NSString *currentEditor = [[LGDefaults standardUserDefaults] objectForKey:@"RecipeEditor"];

    BOOL overrideExists = [LGRecipeOverrides overrideExistsForRecipe:recipe];
    menu = [[NSMenu alloc] init];
    [menu addItem:identifierItem];
    
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

    if (overrideExists) {
        item = [[NSMenuItem alloc] initWithTitle:@"Open Recipe Override" action:@selector(openFile:) keyEquivalent:@""];

        // Reveal in finder menu item
        item2 = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
        item2.representedObject = recipe;
        item2.target = [LGRecipeOverrides class];

    } else {
        item = [[NSMenuItem alloc] initWithTitle:@"Create Override" action:@selector(createOverride:) keyEquivalent:@""];
    }

    item.representedObject = recipe;
    item.target = [LGRecipeOverrides class];

    if (item) {
        [menu addItem:item];
    }

    if (item2) {
        [menu addItem:item2];
    }

    [menu addItem:recipeEditorMenuItem];
    [menu setSubmenu:recipeEditorMenu forItem:recipeEditorMenuItem];
    return menu;
}

@end
