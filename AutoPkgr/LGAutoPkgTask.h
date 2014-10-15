//
//  LGAutoPkgTask.h
//  AutoPkgr
//
//  Created by Eldon on 8/30/14.
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

#import <Foundation/Foundation.h>
#import "LGAutoPkgr.h"

/**
 *  Constant to access recipe key in autopkg search
 */
extern NSString *const kLGAutoPkgRecipeKey;
/**
 *  Constant to access recipe path key in autopkg search
 */
extern NSString *const kLGAutoPkgRecipePathKey;
/**
 *  Constant to access repo name in autopkg search and autopkg repo-list
 */
extern NSString *const kLGAutoPkgRepoKey;
/**
 *  Constant to access local path of the installed repo from autopkg repo-list
 */
extern NSString *const kLGAutoPkgRepoPathKey;

@interface LGAutoPkgTask : NSObject

/**
 *  Arguments passed into autopkg
 */
@property (strong, nonatomic) NSArray *arguments;

/**
 *  stdout from autopkg
 */
@property (strong, nonatomic, readonly) NSString *standardOutString;

/**
 *  stderr from autopkg
 */
@property (strong, nonatomic, readonly) NSString *standardErrString;

/**
 * An array of dictionaries based on the autopkg verb
 * @discussion only, recipe-list, repo-list, and search will return values, all others will return nil;
 */
@property (copy, nonatomic, readonly) NSArray *results;

/**
 *  Observable KVO property indicating the task has completed.
 */
@property (nonatomic, readonly) BOOL complete;

/**
 *  The block to use for providing run status updates asynchronously.
 */
@property (copy) void (^runStatusUpdate)(NSString *message, double progress);

#pragma mark - Instance Methods
/**
 *  Launch task in a synchronous way
 *
 *  @param error NSError object populated should error occur
 *
 *  @return YES if the task was completed successfully, no if the task ended with an error;
 *
 *  @discussion a cancel request will also result in a return of YES;
 */
- (BOOL)launch:(NSError **)error;

/**
 *  Launch task in an asynchronous way
 *
 * @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 *
 * @discussion this runs on a background queue;
 */
- (void)launchInBackground:(void (^)(NSError *error))reply;

/**
 *  Cancel the current task
 *
 *  @return YES if task was successfully canceled, NO is the task is still running.
 */
- (BOOL)cancel;

#pragma mark
/**
 *  Equivelant to /usr/bin/local/autopkg run --recipe-list=xxx --report-plist=xxx
 *
 *  @param recipeList Full path to the recipe list
 *  @param progress   block to be executed whenever new progress information is avaliable.  This block has no return value and takes two arguments: NSString, double
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes two arguments: NSDictionary (with ther report plist data), NSError
 */
- (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg run recipe1 recipe2 ... recipe(n) --report-plist=xxx
 *
 *  @param recipes  Array of recipes to run
 *  @param progress  Block to be executed whenever new progress information is avaliable.  This block has no return value and takes two arguments: NSString, double
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
- (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *message))progress
             reply:(void (^)(NSError *error))reply;

#pragma mark - Class Methods
#pragma mark-- Run methods

/**
 *  Convience Accessor to autopkg run: see runRecipeList:progress:reply for details
 *
 */
+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *message, double taskProgress))progress
                reply:(void (^)(NSDictionary *report, NSError *error))reply;

/**
 *  Convience Accessor for autopkg run: see runRecipes:progress:reply for details
 *
 */
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *message))progress
             reply:(void (^)(NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg search [recipe]
 *
 *  @param recipe recipe to search for
 *  @param reply  The block to be executed on upon task completion. This block has no return value and takes two arguments: NSArray, NSError
 *  @discussion the NSArray in the reply block is and array of dictionaries, each dictionary entry contains 3 items recipe, repo, and repo path.  You can use the kLGAutoPkgRecipeKey, kLGAutoPkgRepoKey, and kLGAutoPkgRepoPathKey strings to access the dictionary entries.
 */
+ (void)search:(NSString *)recipe
         reply:(void (^)(NSArray *results, NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg make-override [recipe]
 *
 *  @param recipe Recipe override file to create
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)makeOverride:(NSString *)recipe
               reply:(void (^)(NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg list-recipes
 *
 *  @param reply  The block to be executed on upon task completion. This block has no return value and takes two arguments: NSArray, NSError
 */
+ (void)listRecipes:(void (^)(NSArray *recipes, NSError *error))reply;
/**
 *  Equivelant to /usr/bin/local/autopkg list-recipes
 *
 *  @return List of recipes
 */
+ (NSArray *)listRecipes;

#pragma mark-- Repo methods
/**
 *  Equivelant to /usr/bin/local/autopkg repo-add [recipe_repo_url]
 *
 *  @param repo repo to add
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoAdd:(NSString *)repo
          reply:(void (^)(NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg repo-remove [repo]
 *
 *  @param repo  repo to remove
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoRemove:(NSString *)repo
             reply:(void (^)(NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg repo-update
 *
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoUpdate:(void (^)(NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg repo-list (Asynchronous)
 *
 *  @param reply  The block to be executed on upon task completion. This block has no return value and takes two arguments: NSArray, NSError
 */
+ (void)repoList:(void (^)(NSArray *repos, NSError *error))reply;

/**
 *  Equivelant to /usr/bin/local/autopkg repo-list (Synchronous)
 *
 *  @return list of installed autopkg repos
 */
+ (NSArray *)repoList;

#pragma mark-- Other
/**
 *  Equivelant to /usr/bin/local/autopkg version
 *
 *  @return version string
 */
+ (NSString *)version;

@end
