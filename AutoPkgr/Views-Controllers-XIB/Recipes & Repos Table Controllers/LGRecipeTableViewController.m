//
//  LGRecipeTableViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/3/2015.
//  Copyright 2015 Eldon Ahrold
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgRecipe.h"
#import "LGAutoPkgRecipeListManager.h"
#import "LGAutoPkgReport.h"
#import "LGAutoPkgTask.h"
#import "LGAutoPkgr.h"
#import "LGRecipeInfoView.h"
#import "LGRecipeOverrides.h"
#import "LGRecipeTableViewController.h"
#import "LGTableCellViews.h"

@interface LGRecipeTableViewController () <NSWindowDelegate, NSPopoverDelegate>

@property (copy, nonatomic) NSMutableArray *recipes;
@property (copy, nonatomic) NSMutableArray *searchedRecipes;

@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;
@property (weak) IBOutlet NSPopUpButton *recipeListButton;

@property (strong) LGAutoPkgRecipeListManager *recipeList;

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

        _recipeList = [[LGAutoPkgRecipeListManager alloc] init];
        [self refreshRecipeList];
    }
}

- (void)reload
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Reload is used to rebuilt the index.
        // nil out _recipes here so when the self.recipes accessor is called it will actually get reconstructed.
        _recipes = nil;
        [self executeAppSearch:self];
        [self refreshRecipeList];
    });
}

- (void)refreshRecipeList
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_recipeListButton removeAllItems];
        [_recipeListButton addItemsWithTitles:_recipeList.recipeLists];
        [_recipeListButton selectItemWithTitle:_recipeList.currentListName];
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
        if (_runTaskDictionary[recipe.Identifier]) {
            [statusCell.progressIndicator startAnimation:tableView];
            statusCell.imageView.hidden = YES;
        }
        else {
            [statusCell.progressIndicator stopAnimation:tableView];
            statusCell.imageView.hidden = NO;

            if ([[recipe valueForKey:NSStringFromSelector(@selector(isMissingParent))] boolValue]) {
                statusCell.imageView.image = [NSImage LGCaution];
            }
            else {
                statusCell.imageView.image = [NSImage LGNoImage];
            }
        }
    }
    else if ([tableColumn.identifier isEqualToString:NSStringFromSelector(@selector(isEnabled))]) {
        statusCell.enabledCheckBox.state = [[recipe valueForKey:tableColumn.identifier] boolValue];
        statusCell.enabledCheckBox.target = recipe;
        statusCell.enabledCheckBox.action = @selector(enableRecipe:);
    }
    else {
        NSString *string = [recipe valueForKey:tableColumn.identifier];
        if (string) {
            statusCell.textField.stringValue = string;
        }
        else {
            statusCell.textField.placeholderString = @"<Missing>";
        }
    }
    return statusCell;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [_searchedRecipes sortUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

#pragma mark - IBActions
- (void)enableRecipes:(NSMenuItem *)sender
{
    NSArray *recipes = sender.representedObject;
    BOOL state = [recipes.firstObject isEnabled];
    [recipes enumerateObjectsUsingBlock:^(LGAutoPkgRecipe *recipe, NSUInteger idx, BOOL *stop) {
        recipe.enabled = !state;
    }];

    [self.recipeTableView reloadData];
}

- (void)updateRecipes:(NSMenuItem *)sender
{
    NSArray *recipes = sender.representedObject;
    // Start spinning.

    [LGAutoPkgTask runRecipes:recipes
                     progress:nil
                        reply:^(NSDictionary *report, NSError *error){
                            // Remove from run dict.
                        }];
}

- (IBAction)addRecipeList:(NSButton *)sender
{
    NSError *error;
    NSString *str;
    if ((str = [self promptForRecipeListName])) {
        if (![_recipeList addRecipeList:str error:&error]) {
            [NSApp presentError:error];
        }
        else {
            [self reload];
        }
    }
}

- (IBAction)removeRecipeList:(NSButton *)sender
{
    NSError *error;
    if (![_recipeList removeRecipeList:_recipeListButton.title error:&error]) {
        [NSApp presentError:error];
    }
    else {
        [self reload];
    }
}

- (IBAction)recipeListSelectionChanged:(NSPopUpButton *)sender
{
    _recipeList.currentListName = sender.title;
    [self reload];
}

- (NSString *)promptForRecipeListName
{
    NSString *listName = nil;
    NSString *promptString = NSLocalizedString(@"Add a new recipe list?", nil);

    NSAlert *alert = [NSAlert alertWithMessageText:promptString
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];

    NSTextField *input = [[NSTextField alloc] init];
    [input setFrame:NSMakeRect(0, 0, 300, 24)];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        listName = [input stringValue];
        if (!listName || [listName isEqualToString:@""]) {
            return [self promptForRecipeListName];
        }
    }
    return listName;
}

#pragma mark - Filtering
- (void)executeAppSearch:(id)sender
{
    [_recipeTableView beginUpdates];
    [_recipeTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRecipes.count)] withAnimation:NSTableViewAnimationEffectNone];

    if (_recipeSearchField.stringValue.length == 0) {
        _searchedRecipes = self.recipes;
    }
    else {
        NSString *searchString = _recipeSearchField.stringValue;

        // Execute search both on Name and Identifier keys.
        NSMutableArray *predicates = [[NSMutableArray alloc] init];
        for (NSString *key in @[ kLGAutoPkgRecipeNameKey, kLGAutoPkgRecipeIdentifierKey ]) {
            [predicates addObject:[NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", key, searchString]];
        }

        NSCompoundPredicate *recipeSearchPredicate = [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:predicates];
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
- (void)runRecipesFromMenu:(NSMenuItem *)item
{
    NSIndexSet *recipeRows = item.representedObject;

    if (!_runTaskDictionary) {
        _runTaskDictionary = [[NSMutableDictionary alloc] init];
    }

    __block BOOL runMakeCatalogs = NO;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF.Identifier contains[cd] '.munki'"];
    NSMutableArray *recipes = [[NSMutableArray alloc] initWithCapacity:recipeRows.count];

    [recipeRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        LGAutoPkgRecipe *recipe = _searchedRecipes[idx];
        [recipes addObject:recipe.Identifier];
        if ([predicate evaluateWithObject:recipe]) {
            runMakeCatalogs = NO;
        }
    }];

    if (runMakeCatalogs) {
        [recipes addObject:@"MakeCatalogs.munki"];
    }

    LGAutoPkgTask *runTask = [LGAutoPkgTask runRecipesTask:recipes];
    [recipes enumerateObjectsUsingBlock:^(id recipes, NSUInteger idx, BOOL *_Nonnull stop) {
        [_runTaskDictionary setObject:runTask forKey:recipes];
    }];

    // This runs a recipe from the table's contextual menu.
    runTask.progressUpdateBlock = ^(NSString *message, double progress) {
        NSLog(@"Run status: %@", message);
    };

    NSIndexSet *colIdxSet = [[NSIndexSet alloc] initWithIndex:[_recipeTableView columnWithIdentifier:kLGAutoPkgRecipeCurrentStatusKey]];

    [_recipeTableView reloadDataForRowIndexes:recipeRows columnIndexes:colIdxSet];

    __weak typeof(runTask) weakTask = runTask;
    [runTask launchInBackground:^(NSError *error) {
        __strong typeof(runTask) strongTask = weakTask;

        LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:strongTask.report];
        NSError *failureError = report.failureError;

        if (error || failureError) {
            [[NSAlert alertWithError:error ?: failureError] runModal];
        }
        else {
            LGUpdatedApplication *updatedApplication = report.updatedApplications.firstObject;
            if (updatedApplication) {
                NSUserNotification *notification = [[NSUserNotification alloc] init];
                NSString *informativeTextFormat = NSLocalizedString(@"%@ of %@ was downloaded.",
                                                                    @"NSUserNotification info message presented after single recipe run.");
                NSString *versionString;
                if (!updatedApplication.version || [updatedApplication.version.lowercaseString isEqualToString:@"Unknown version".lowercaseString]) {
                    versionString = @"A newer version";
                }
                else {
                    versionString = quick_formatString(@"Version %@", updatedApplication.version);
                }

                notification.informativeText = quick_formatString(informativeTextFormat, versionString, updatedApplication.name);

                [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
            }
        }

        [_runTaskDictionary removeObjectsForKeys:recipes];
        [_recipeTableView reloadDataForRowIndexes:recipeRows columnIndexes:colIdxSet];

        // If there are no more run tasks, don't keep the dictionary around.
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

    NSIndexSet *set = _recipeTableView.selectedRowIndexes;

    NSMutableIndexSet *update = [[NSMutableIndexSet alloc] init];
    NSMutableArray *enable = [[NSMutableArray alloc] init],
                   *disable = [[NSMutableArray alloc] init];

    [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        LGAutoPkgRecipe *recipe = _searchedRecipes[idx];
        if (recipe.isEnabled) {
            [disable addObject:recipe];
        }
        else {
            [enable addObject:recipe];
        }
        [update addIndex:idx];
    }];

    id task = _runTaskDictionary[recipe.Identifier];
    if (!task && update.count) {
        NSString *title = update.count > 1 ? @"Run Selected Recipes" : @"Run This Recipe Only";
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(runRecipesFromMenu:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = update;
        [menu addItem:item];
    }

    if (task) {
        NSMenuItem *cancelItem = [[NSMenuItem alloc] initWithTitle:@"Cancel Run" action:@selector(cancel) keyEquivalent:@""];
        cancelItem.target = task;
        [menu addItem:cancelItem];
    }

    if (set.count > 1) {
        if (enable.count) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Enable Selected Recipes" action:@selector(enableRecipes:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = enable;
            [menu addItem:item];
        }

        if (disable.count) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Disable Selected Recipes" action:@selector(enableRecipes:) keyEquivalent:@""];
            item.target = self;
            item.representedObject = disable;
            [menu addItem:item];
        }
        return menu;
    }

    NSMenuItem *infoItem = [[NSMenuItem alloc] initWithTitle:@"Get Info" action:@selector(openInfoPanelFromMenu:) keyEquivalent:@""];
    infoItem.representedObject = recipe;
    infoItem.target = self;
    [menu addItem:infoItem];

    if (recipe.ParentRecipe) {
        if (recipe.isMissingParent) {
            NSLog(@"Missing Parent Recipe");
        }
        NSString *parent = [@"Parent Recipe: " stringByAppendingString:recipe.ParentRecipe];
        [menu addItemWithTitle:parent action:nil keyEquivalent:@""];
    }

    // Set up menu items for overrides.

    if ([LGRecipeOverrides overrideExistsForRecipe:recipe]) {
        // "Open Recipe Override" menu item.
        NSMenuItem *openRecipeItem = [[NSMenuItem alloc] initWithTitle:@"Open Recipe Override" action:@selector(openFile:) keyEquivalent:@""];
        openRecipeItem.target = [LGRecipeOverrides class];
        openRecipeItem.representedObject = recipe;
        [menu addItem:openRecipeItem];

        // "Reveal in Finder" menu item.
        NSMenuItem *showInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Reveal in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
        showInFinderItem.representedObject = recipe;
        showInFinderItem.target = [LGRecipeOverrides class];
        [menu addItem:showInFinderItem];

        // "Update Trust Info" menu item.
        NSMenuItem *trustOverrideItem = [[NSMenuItem alloc] initWithTitle:@"Update Trust Info for Override" action:@selector(trustOverride:) keyEquivalent:@""];
        trustOverrideItem.representedObject = recipe;
        trustOverrideItem.target = [LGRecipeOverrides class];
        [menu addItem:trustOverrideItem];

        // "Delete Override" menu item.
        NSMenuItem *removeOverrideItem = [[NSMenuItem alloc] initWithTitle:@"Remove Override" action:@selector(deleteOverride:) keyEquivalent:@""];
        removeOverrideItem.representedObject = recipe;
        removeOverrideItem.target = [LGRecipeOverrides class];
        [menu addItem:removeOverrideItem];
    }
    else {
        NSMenuItem *createOverrideItem = [[NSMenuItem alloc] initWithTitle:@"Create Override" action:@selector(createOverride:) keyEquivalent:@""];
        createOverrideItem.representedObject = recipe;
        createOverrideItem.target = [LGRecipeOverrides class];
        [menu addItem:createOverrideItem];
    }

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
