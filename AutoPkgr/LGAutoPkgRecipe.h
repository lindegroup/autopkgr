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

@interface LGAutoPkgRecipe : NSObject
- (instancetype)init __attribute__((unavailable("init not available")));

- (instancetype)initWithRecipeFile:(NSURL *)recipeFile isOverride:(BOOL)isOverride;
@property (copy, nonatomic, readonly) NSDictionary *recipePlist;

@property (copy, nonatomic, readonly) NSString *Identifier;
@property (copy, nonatomic, readonly) NSString *Name;
@property (copy, nonatomic, readonly) NSString *Description;
@property (copy, nonatomic, readonly) NSString *ParentRecipe;
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

+ (NSArray *)allRecipes;
+ (NSArray *)allRecipesFilteringOverlaps:(BOOL)filterOverlaps;

+ (NSSet *)activeRecipes;

/**
 *  Migrate a recipe_list.txt file from recipe shortnames to recipe identifiers.
 *
 *  @param error populated error object if any error occurs during migration.
 *
 *  @return YES if conversion was successful, NO if any error occurred, even minor errors.
 */
//
+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error;

+ (void)removeRecipeFromRecipeList:(NSString *)recipe;

+ (NSString *)defaultRecipeList;

@end
