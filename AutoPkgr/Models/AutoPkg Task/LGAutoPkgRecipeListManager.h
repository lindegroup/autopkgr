//
//  LGAutoPkgRecipeListManager.h
//  AutoPkgr
//
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

#import <Foundation/Foundation.h>

/**
 *  Manager class to add, remove, and select 
 *  the recipe list used during autopkg execution
 */
@interface LGAutoPkgRecipeListManager : NSObject

/**
 *  The recipe list used during autopkg execution.
 */
@property (copy) NSString *currentListName;

/**
 *  The file path to the currently used recipe list.
 *  @note This is ~/Library/Application Support/AutoPkgr/xyz.txt
 */
@property (copy, readonly) NSString *currentListPath;

/**
 *  Array of recipe lists.
 *  @note This is representative of the list of files.
 */
@property (copy, readonly) NSArray *recipeLists;
@property (copy, nonatomic) void (^changeHandler)(NSArray *currentList);

/**
 *  Add a recipe list file
 *
 *  @param list  Name of the recipe list
 *  @param error Populated error object on failure, nil on success.
 *
 *  @return YES on success, no otherwise
 */
- (BOOL)addRecipeList:(NSString *)list error:(NSError **)error;

/**
 *  Remove a recipe list file by name
 *
 *  @param list  Name of the recipe list
 *  @param error Populated error object on failure, nil on success.
 *
 *  @return YES on success, no otherwise
 */
- (BOOL)removeRecipeList:(NSString *)list error:(NSError **)error;

@end
