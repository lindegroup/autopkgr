//
//  LGApplications.h
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

#import <Foundation/Foundation.h>
#import "LGAutoPkgTask.h"
#import "LGTableView.h"

@interface LGRecipes : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

/**
 *  Path to the recipe_list.txt file.
 *
 *  @return Path to the recipe_list.txt file
 */
+ (NSString *)recipeList;

/**
 *  Remove a recipe from the recipe list by name.
 *
 *  @param recipe Name of the recipe to remove
 */
+ (void)removeRecipeFromRecipeList:(NSString *)recipe;

/**
 *  Write an array to the recipe list file.
 *
 *  @param recipes array of recipes
 */
+ (void)writeRecipeList:(NSMutableOrderedSet *)recipes;

/**
 *  Array of the recipes currently in the recipe_list.txt.
 *
 *  @return set of recipes.
 */
+ (NSSet *)getActiveRecipes;

/**
 *  Migrate a recipe_list.txt file from recipe shortnames to recipe identifiers.
 *
 *  @param error populated error object if any error occurs during migration.
 *
 *  @return YES if conversion was successful, NO if any error occurred, even minor errors.
 */
+ (BOOL)migrateToIdentifiers:(NSError **)error;

/**
 *  reload the Recipe TableView
 */
- (void)reload;

- (NSMenu *)contextualMenuForRecipeAtRow:(NSInteger)row;

@end
