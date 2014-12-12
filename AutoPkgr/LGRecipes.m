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
    _recipes = [LGAutoPkgTask listRecipes];
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
        return @([_activeRecipes containsObject:[_searchedRecipes objectAtIndex:row]]);
    } else if ([[tableColumn identifier] isEqualToString:@"recipeName"]) {
        return [_searchedRecipes objectAtIndex:row];
    }

    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"recipeCheckbox"]) {
        NSMutableArray *workingArray = [NSMutableArray arrayWithArray:_activeRecipes];
        if ([object isEqual:@YES]) {
            [workingArray addObject:[_searchedRecipes objectAtIndex:row]];
        } else {
            NSUInteger index = [workingArray indexOfObject:[_searchedRecipes objectAtIndex:row]];
            if (index != NSNotFound) {
                [workingArray removeObjectAtIndex:index];
            } else {
                NSLog(@"Cannot find item %@ in workingArray.", [_searchedRecipes objectAtIndex:row]);
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
        if (![_recipes containsObject:string]) {
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

    NSString *recipe_list = [workingArray componentsJoinedByString:@"\n"];

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
        NSPredicate *recipeSearchPred = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] %@",[_recipeSearchField stringValue]];
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

+ (NSString *)recipeList
{
    NSString *applicationSupportDirectory = [LGHostInfo getAppSupportDirectory];
    return [applicationSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
}

@end
