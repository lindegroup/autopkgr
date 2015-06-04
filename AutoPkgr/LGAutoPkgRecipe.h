// LGAutoPkgRecipe.h
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

#import <Foundation/Foundation.h>

/*
 * LGAutoPkgRecipes is a native Objective-c implementation of `autopkg  list-recipes`
 * It's much faster than using python and since it creates objects, it has
 * some AutoPkg(r) specific features such as the ability to enable/diable a recipe.
 */
@interface LGAutoPkgRecipe : NSObject
- (instancetype)init __attribute__((unavailable("all recipes are readonly, use a class method to get a list")));
+ (instancetype) new __attribute__((unavailable("all recipes are readonly, use a class method to get a list")));

- (instancetype)initWithRecipeFile:(NSURL *)recipeFile isOverride:(BOOL)isOverride;

/**
 *  Enable a recipe using a IBObject.
 *
 *  @param sender object sending message.
 *  @note this is basically a proxy that changes the `enabled` property to the `sender.state`.
 */
- (IBAction)enableRecipe:(NSButton *)sender;

@property (copy, nonatomic, readonly) NSDictionary *recipePlist;

@property (copy, nonatomic, readonly) NSString *Identifier;
@property (copy, nonatomic, readonly) NSString *Name;
@property (copy, nonatomic, readonly) NSString *Description;
@property (copy, nonatomic, readonly) NSString *ParentRecipe;

@property (copy, nonatomic, readonly) NSString *recipeRepo;
@property (copy, nonatomic, readonly) NSURL *recipeRepoURL;

/**
 *  An array of strings of the parent recipe identifiers
 */
@property (copy, nonatomic, readonly) NSArray *ParentRecipes;

@property (copy, nonatomic, readonly) NSString *MinimumVersion;
@property (copy, nonatomic, readonly) NSString *FilePath;

@property (copy, nonatomic, readonly) NSDictionary *Input;
@property (copy, nonatomic, readonly) NSArray *Process;

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, assign, readonly) BOOL isOverride;
@property (nonatomic, assign, readonly) BOOL isMissingParent;

@property (nonatomic, assign, readonly) BOOL hasCheckPhase;
@property (nonatomic, assign, readonly) BOOL buildsPackage;

/* Bool value indicating an error with the recipe, such as it's missing
 * it's parent recipe, (or someday a required processor ) 
 */
@property (nonatomic, assign, readonly) BOOL recipeConfigError;

/**
 *  Get a list of all recipes and overrides.
 *  @note this will filter out parent recipes of overrides with the same name.
 *
 *  @return Array of LGAutoPkgRecipes
 */
+ (NSArray *)allRecipes;

/**
 *  Get a list of all recipes and overrides.
 *
 *  @param filterOverlaps whether to filter out parent recipes with the same name as an override.
 *
 *  @return Array of LGAutoPkgRecipes
 */
+ (NSArray *)allRecipesFilteringOverlaps:(BOOL)filterOverlaps;

/**
 *  Set of recipes 
 *
 *  @return Set of recipes to run.
 */
+ (NSSet *)activeRecipes;

/**
 *  Migrate a recipe_list.txt file from recipe shortnames to recipe identifiers.
 *
 *  @param error populated error object if any error occurs during migration.
 *
 *  @return YES if conversion was successful, NO if any error occurred, even minor errors.
 */
+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error;

/**
 *  Remove a recipe with a given name from the list of active recipes
 *
 *  @param recipe Identifier string of the recipe to remove.
 */
+ (BOOL)removeRecipeFromRecipeList:(NSString *)recipe;

/**
 *  File path of the default recipe_list.txt file used to run autopkg.
 *
 *  @return File path.
 */
+ (NSString *)defaultRecipeList;

@end
