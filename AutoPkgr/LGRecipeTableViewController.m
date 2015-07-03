//
//  LGRecipeTableViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/3/2015.
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGRecipeTableViewController.h"
#import "LGTableCellViews.h"
#import "LGRecipeInfoView.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgRecipe.h"
#import "LGAutoPkgTask.h"
#import "LGRecipeOverrides.h"

@interface LGRecipeTableViewController () <NSWindowDelegate, NSPopoverDelegate>

@property (copy, nonatomic) NSMutableArray *recipes;
@property (copy, nonatomic) NSMutableArray *searchedRecipes;

@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;

@end

@implementation LGRecipeTableViewController {
    NSMutableDictionary *_runTaskDictionary;
    NSString *_currentRunningRecipe;
    BOOL _isAwake;
}

static NSString *const kLGAutoPkgRecipeIsEnabledKey = @"isEnabled";
static NSString *const kLGAutoPkgRecipeCurrentStatusKey = @"currentStatus";

- (void)awakeFromNib
{
    if (!_isAwake) {
        _isAwake = YES;
        [_recipeSearchField setTarget:self];
        [_recipeSearchField setAction:@selector(executeAppSearch:)];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didCreateOverride:) name:kLGNotificationOverrideCreated object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didDeleteOverride:) name:kLGNotificationOverrideDeleted object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:kLGNotificationReposModified object:nil];

        _searchedRecipes = self.recipes;
    }
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
    return _searchedRecipes.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    LGAutoPkgRecipe *recipe = [_searchedRecipes objectAtIndex:row];
    LGRecipeStatusCellView *statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

    if ([tableColumn.identifier isEqualToString:kLGAutoPkgRecipeCurrentStatusKey]) {
        if (_runTaskDictionary[recipe.Name]) {
            [statusCell.progressIndicator startAnimation:tableView];
            statusCell.imageView.hidden = YES;
        } else {
            [statusCell.progressIndicator stopAnimation:tableView];
            statusCell.imageView.hidden = NO;

            if ([[recipe valueForKey:NSStringFromSelector(@selector(isMissingParent))] boolValue]) {
                statusCell.imageView.image = [NSImage LGCaution];
            } else {
                statusCell.imageView.image = [NSImage LGNoImage];
            }
        }
    } else if ([tableColumn.identifier isEqualToString:NSStringFromSelector(@selector(isEnabled))]) {
        statusCell.enabledCheckBox.state = [[recipe valueForKey:tableColumn.identifier] boolValue];
        statusCell.enabledCheckBox.target = recipe;
        statusCell.enabledCheckBox.action = @selector(enableRecipe:);

    } else {
        statusCell.textField.stringValue = [recipe valueForKey:tableColumn.identifier];
    }

    return statusCell;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
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

#pragma mark - Run Task Menu Actions
- (void)runRecipeFromMenu:(NSMenuItem *)item
{
    NSInteger recipeRow = [item.representedObject integerValue];
    LGAutoPkgRecipe *recipe = _searchedRecipes[recipeRow];

    if (!_runTaskDictionary) {
        _runTaskDictionary = [[NSMutableDictionary alloc] init];
    }

    // This runs a recipe from the Table's contextual menu...
    LGAutoPkgTask *runTask = [LGAutoPkgTask runRecipesTask:@[ recipe.Name ]];

    [_runTaskDictionary setObject:runTask forKey:recipe.Name];

    runTask.progressUpdateBlock = ^(NSString *message, double progress) {
        NSLog(@"%@", message);
    };

    NSIndexSet *rowIdxSet = [[NSIndexSet alloc] initWithIndex:recipeRow];
    NSIndexSet *colIdxSet = [[NSIndexSet alloc] initWithIndex:[_recipeTableView columnWithIdentifier:kLGAutoPkgRecipeCurrentStatusKey]];
    [_recipeTableView reloadDataForRowIndexes:rowIdxSet columnIndexes:colIdxSet];

    [runTask launchInBackground:^(NSError *error) {
        if (error) {
            [[NSAlert alertWithError:error] runModal];
        }

        [_runTaskDictionary removeObjectForKey:recipe.Name];
        [_recipeTableView reloadDataForRowIndexes:rowIdxSet columnIndexes:colIdxSet];

        // If there are no more run tasks don't keep the dictioanry around...
        if (_runTaskDictionary.count == 0) {
            _runTaskDictionary = nil;
        }
    }];
}

- (void)openInfoPanelFromMenu:(NSMenuItem *)item
{
    [self openInfoPanel:item.representedObject];
}

- (void)openInfoPanel:(LGAutoPkgRecipe *)recipe
{
    LGRecipeInfoView *infoView = [[LGRecipeInfoView alloc] initWithRecipe:recipe];
    NSPopover *infoPopover = infoPopover = [[NSPopover alloc] init];
    infoPopover.behavior = NSPopoverBehaviorTransient;

    infoPopover.contentViewController = infoView;
    infoPopover.delegate = self;

    if (!infoPopover.isShown) {
        [infoPopover showRelativeToRect:_recipeTableView.contextualMenuMouseLocal
                                 ofView:_recipeTableView
                          preferredEdge:NSMinYEdge];
    }
}

- (void)popoverDidClose:(NSNotification *)notification
{
    NSPopover *infoPopover = notification.object;
    infoPopover.contentViewController = nil;
    infoPopover = nil;
}

#pragma mark - Contextual Menu
- (NSMenu *)contextualMenuForRow:(NSInteger)row
{
    NSMenu *menu = [[NSMenu alloc] init];
    LGAutoPkgRecipe *recipe = [_searchedRecipes objectAtIndex:row];

    NSMenuItem *infoItem = [[NSMenuItem alloc] initWithTitle:@"Get Info" action:@selector(openInfoPanelFromMenu:) keyEquivalent:@""];
    infoItem.representedObject = recipe;
    infoItem.target = self;
    [menu addItem:infoItem];

    NSMenuItem *runMenuItem;
    if (_runTaskDictionary[recipe.Name]) {
        runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Cancel Run" action:@selector(cancel) keyEquivalent:@""];
        runMenuItem.target = _runTaskDictionary[recipe.Name];
        [menu addItem:runMenuItem];
    } else {
        runMenuItem = [[NSMenuItem alloc] initWithTitle:@"Run This Recipe Only" action:@selector(runRecipeFromMenu:) keyEquivalent:@""];
        runMenuItem.target = self;
        runMenuItem.representedObject = @(row);
        [menu addItem:runMenuItem];
    }

    if (recipe.ParentRecipe) {
        if (recipe.isMissingParent) {
            NSLog(@"Missing Parent Recipe");
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
        NSMenuItem *showInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Reveal in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
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
