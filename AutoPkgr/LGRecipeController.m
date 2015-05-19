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

#import "LGRecipeController.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgRecipe.h"

#import "LGRecipeOverrides.h"

@interface LGRecipeController ()

@property (copy, nonatomic) NSMutableArray *recipes;
@property (copy, nonatomic) NSMutableArray *searchedRecipes;

@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;

@end

@implementation LGRecipeController {
    LGAutoPkgTask *_runTask;
    NSString *_currentRunningRecipe;
}

static NSString *const kLGAutoPkgRecipeIsEnabledKey = @"isEnabled";

- (void)awakeFromNib
{
    [_recipeSearchField setTarget:self];
    [_recipeSearchField setAction:@selector(executeAppSearch:)];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCreateOverride:) name:kLGNotificationOverrideCreated object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDeleteOverride:) name:kLGNotificationOverrideDeleted object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:kLGNotificationReposModified object:nil];

    _searchedRecipes = self.recipes;
    [_recipeTableView reloadData];
}

- (void)reload
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reload is used to rebuilt the index.
        // nil out _recipes here so when the self.recipes accessor is called
        // it will actually get reconstructed.
        _recipes = nil;
        [self executeAppSearch:self];
    });
}

#pragma mark - Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRecipes count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    return [[_searchedRecipes objectAtIndex:row] valueForKey:tableColumn.identifier];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:kLGAutoPkgRecipeIsEnabledKey]) {

        LGAutoPkgRecipe *recipe = [_searchedRecipes objectAtIndex:row];
        if (recipe.isMissingParent) {
            return [LGError presentErrorWithCode:kLGErrorMissingParentRecipe];
        }
        // Setting the recipe.enabled property will add/remove the recipe to the recipe_list.txt
        recipe.enabled = [object boolValue];
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
        _recipes = [[LGAutoPkgRecipe allRecipes] mutableCopy];
        [_recipes sortUsingDescriptors:_recipeTableView.sortDescriptors];
    }

    return _recipes;
}

#pragma mark- Run Task Menu Actions
- (void)cancelTask {
    if (_runTask) {
        [_runTask cancel];
    }
    _runTask = nil;
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

    LGAutoPkgRecipe *recipe = [_searchedRecipes objectAtIndex:row];

    menu = [[NSMenu alloc] init];

    NSMenuItem *runMenuItem;
    if (_runTask.isExecuting) {
        runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Cancel Run" action:@selector(cancel) keyEquivalent:@""];
        runMenuItem.target = _runTask;
        [menu addItem:runMenuItem];
    } else {
        runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Run this recipe" action:@selector(runRecipeFromMenu:) keyEquivalent:@""];
        runMenuItem.target = self;
        runMenuItem.representedObject = recipe.Name;
        [menu addItem:runMenuItem];
    }

    if (recipe.ParentRecipe) {
        if (recipe.isMissingParent) {
            NSLog(@"Missing parent recipe.");
        }
        NSString *parent = [@"Parent Recipe: " stringByAppendingString:recipe.ParentRecipe];
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

    // Setup menu items for overrides.

    if ([LGRecipeOverrides overrideExistsForRecipe:recipe]) {
        NSMenuItem *openRecipeItem = [[NSMenuItem alloc] initWithTitle:@"Open Recipe Override" action:@selector(openFile:) keyEquivalent:@""];
        openRecipeItem.target = [LGRecipeOverrides class];
        openRecipeItem.representedObject = recipe;
        [menu addItem:openRecipeItem];

        // Reveal in finder menu item
        NSMenuItem *showInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
        showInFinderItem.representedObject = recipe;
        showInFinderItem.target = [LGRecipeOverrides class];
        [menu addItem:showInFinderItem];

        // "Delete Override" menu item
        NSMenuItem *removeOverrideItem = [[NSMenuItem alloc] initWithTitle:@"Remove Override" action:@selector(deleteOverride:) keyEquivalent:@""];

        removeOverrideItem.representedObject = recipe;
        removeOverrideItem.target = [LGRecipeOverrides class];
        [menu addItem:removeOverrideItem];

    } else {
        NSMenuItem *openRecipeItem = [[NSMenuItem alloc] initWithTitle:@"Create Override" action:@selector(createOverride:) keyEquivalent:@""];
        openRecipeItem.representedObject = recipe;
        openRecipeItem.target = [LGRecipeOverrides class];
        [menu addItem:openRecipeItem];
    }

    // Add the editor menu last.
    [menu addItem:recipeEditorMenuItem];
    [menu setSubmenu:recipeEditorMenu forItem:recipeEditorMenuItem];

    return menu;
}

#pragma mark - Notifications
- (void)didCreateOverride:(NSNotification *)aNotification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self reload];
    }];
}

- (void)didDeleteOverride:(NSNotification *)aNotification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self reload];
    }];
}

@end
