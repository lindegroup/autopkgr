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
#import "LGProgressDelegate.h"

@class LGAutoPkgTaskManager;
@class LGAutoPkgTask;
@class LGAutoPkgTaskResponseObject;
/**
 *  Constant to access recipe key in autopkg search or recipe-list
 */
extern NSString *const kLGAutoPkgRecipeNameKey;
/**
 *  Constant to access recipe identifier in autopkg recipe-list
 */
extern NSString *const kLGAutoPkgRecipeIdentifierKey;
/**
 *  Constant to access recipe's ParentRecipe in autopkg recipe-list
 */
extern NSString *const kLGAutoPkgRecipeParentKey;
/**
 *  Constant to access recipe path key in autopkg search
 */
extern NSString *const kLGAutoPkgRecipePathKey;
/**
 *  Constant to access repo name in autopkg search and autopkg repo-list
 */
extern NSString *const kLGAutoPkgRepoNameKey;
/**
 *  Constant to access local path of the installed repo from autopkg repo-list
 */
extern NSString *const kLGAutoPkgRepoPathKey;
/**
 *  Constant to access git url for the repo from autopkg repo-list
 */
extern NSString *const kLGAutoPkgRepoURLKey;

#pragma mark Task Status Delegate
@protocol LGTaskStatusDelegate <NSObject>
- (void)didReceiveStatusUpdate:(LGAutoPkgTaskResponseObject *)object;
- (void)didCompleteOperation:(LGAutoPkgTaskResponseObject *)object;
@end

#pragma mark - AutoPkg Task Manager
/**
 *  Task manager to handle both Asynchronous and Synchronous LGAutoPkgTask operations.
 */
@interface LGAutoPkgTaskManager : NSOperationQueue

/**
 *  Progress delegate
 */
@property (weak, nonatomic) id<LGProgressDelegate> progressDelegate;

/**
 *  Progress update block
 */
@property (copy) void (^progressUpdateBlock)(NSString *message, double progress);

#pragma mark-- NSOperation Queue --
/**
 *  Subclass override to produce warning if an incorrect operation is submitted
 *
 *  @param op LGAutoPkgTask
 */
- (void)addOperation:(LGAutoPkgTask *)op;

/**
 *  Cancel all tasks the task manager is responsible for.
 *
 *  @return YES if task was successfully canceled, NO is the task is still running.
 */
- (void)cancel;

#pragma mark-- Convenience Methods --
/**
 *  Equivalent to /usr/bin/local/autopkg run --recipe-list=xxx --report-plist=xxx
 *
 *  @param recipeList Full path to the recipe list
 *  @param updateRepo whether the repos should be updated prior to run
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes two arguments: NSDictionary (with the report plist data), NSError
 *  @note to receive progress messages from this operation the LGProgressDelegate protocol needs to be implemented and the task manager's progressDelegate property set.
 */
- (void)runRecipeList:(NSString *)recipeList
           updateRepo:(BOOL)updateRepo
                reply:(void (^)(NSDictionary *report, NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg run recipe1 recipe2 ... recipe(n) --report-plist=xxx
 *
 *  @param recipes  Array of recipes to run
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes two arguments: NSDictionary (with the report plist data), NSError
 *  @note to receive progress messages from this operation the LGProgressDelegate protocol needs to be implemented and the task manager's progressDelegate property set.
 */
- (void)runRecipes:(NSArray *)recipes
             reply:(void (^)(NSDictionary *report, NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg repo-update all
 *
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 *  @note to receive progress messages from this operation the LGProgressDelegate protocol needs to be implemented and the task manager's progressDelegate property set.
 */
- (void)repoUpdate:(void (^)(NSError *error))reply;

@end

#pragma mark - AutoPkg Task
@interface LGAutoPkgTask : NSOperation <LGTaskStatusDelegate>

/**
 *  Task status delegate gets raw output in the form of an LGAutoPkgTaskResponseObject during both progress updates and task completion.
 *  @note This is set to self by default, only override with good reason.
 */
@property (weak, nonatomic) id<LGTaskStatusDelegate> taskStatusDelegate;

/**
 *  Progress delegate that gets status update messages and progress percent.
 *  @note Currently this only handles status updates, not start/stop
 */
@property (weak, nonatomic) id<LGProgressDelegate> progressDelegate;

/**
 *  Arguments passed into autopkg
 */
@property (copy, nonatomic) NSArray *arguments;

/**
 *  stdout from autopkg
 */
@property (copy, nonatomic, readonly) NSString *standardOutString;

/**
 *  stderr from autopkg
 */
@property (copy, nonatomic, readonly) NSString *standardErrString;

/**
 * An array of dictionaries based on the autopkg verb
 * @discussion only, recipe-list, repo-list, and search will return values, all others will return nil;
 */
@property (copy, nonatomic, readonly) NSArray *results;

/**
 *  The block to use for providing run status updates asynchronously.
 */
@property (copy) void (^progressUpdateBlock)(NSString *message, double progress);

#pragma mark - Instance Methods
/**
 *  Launch task in a synchronous way
 *
 *  @return YES if the task was completed successfully, no if the task ended with an error;
 *
 *  @discussion a cancel request will also result in a return of YES;
 */
- (void)launch;

/**
 *  Launch task in an asynchronous way
 *
 * @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 *
 * @discussion this runs on a background queue;
 */
- (void)launchInBackground:(void (^)(NSError *error))reply;

#pragma mark - Class Methods

#pragma mark-- Recipe methods --
/**
 *  Convenience Accessor to autopkg run: see runRecipeList:progress:reply for details
 *
 */
+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *message, double taskProgress))progress
                reply:(void (^)(NSDictionary *report, NSError *error))reply;

/**
 *  Convenience Accessor for autopkg run: see runRecipes:progress:reply for details
 *
 */
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *, double taskProgress))progress
             reply:(void (^)(NSDictionary *, NSError *))reply;
/**
 *  Equivalent to /usr/bin/local/autopkg search [recipe]
 *
 *  @param recipe recipe to search for
 *  @param reply  The block to be executed on upon task completion. This block has no return value and takes two arguments: NSArray, NSError
 *  @discussion the NSArray in the reply block is and array of dictionaries, each dictionary entry contains 3 items recipe, repo, and repo path.  You can use the kLGAutoPkgRecipeKey, kLGAutoPkgRepoKey, and kLGAutoPkgRepoPathKey strings to access the dictionary entries.
 */
+ (void)search:(NSString *)recipe
         reply:(void (^)(NSArray *results, NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg make-override [recipe]
 *
 *  @param recipe Recipe override file to create
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes two arguments: NSString representing the full path the the newly created override and NSError that is populated should an error occur.
 */
+ (void)makeOverride:(NSString *)recipe
               reply:(void (^)(NSString *newOverrideFile, NSError *error))reply;

+ (void)makeOverride:(NSString *)recipe name:(NSString *)name
               reply:(void (^)(NSString *newOverrideFile, NSError *error))reply;
/**
 *  Equivalent to /usr/bin/local/autopkg list-recipes
 *
 *  @return List of recipes
 */
+ (NSArray *)listRecipes;

#pragma mark-- Repo methods --
/**
 *  Equivalent to /usr/bin/local/autopkg repo-add [recipe_repo_url]
 *
 *  @param repo repo to add
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoAdd:(NSString *)repo
          reply:(void (^)(NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg repo-remove [repo]
 *
 *  @param repo  repo to remove
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoRemove:(NSString *)repo
             reply:(void (^)(NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg repo-update
 *
 *  @param reply The block to be executed on upon task completion. This block has no return value and takes one argument: NSError
 */
+ (void)repoUpdate:(void (^)(NSString *, double taskProgress))progress
             reply:(void (^)(NSError *error))reply;

/**
 *  Equivalent to /usr/bin/local/autopkg repo-list (Synchronous)
 *
 *  @return list of installed autopkg repos
 */
+ (NSArray *)repoList;

#pragma mark-- Convenience Initializers --
+ (LGAutoPkgTask *)runRecipeTask:(NSArray *)recipes;
+ (LGAutoPkgTask *)runRecipeListTask;
+ (LGAutoPkgTask *)searchTask:(NSString *)recipe;
+ (LGAutoPkgTask *)repoUpdateTask;
+ (LGAutoPkgTask *)addRepoTask:(NSString *)repo;

#pragma mark-- Other --
/**
 *  Equivalent to /usr/bin/local/autopkg version
 *
 *  @return version string
 */
+ (NSString *)version;

@end

#pragma mark - AutoPkg Response / Progress message Object
@interface LGAutoPkgTaskResponseObject : NSObject <NSSecureCoding>
#pragma mark-- Completion Items --
@property (copy, nonatomic) NSError *error;
@property (copy, nonatomic) NSDictionary *report;
@property (copy, nonatomic) NSArray *results;

#pragma mark-- Progress Items --
@property (copy, nonatomic) NSString *progressMessage;
@property (assign, nonatomic) double progress;
@end
