//
//  LGAutoPkgTask.h
//  AutoPkgr
//
//  Created by Eldon on 8/30/14.
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

extern NSString *const kLGAutoPkgRecipeKey;
extern NSString *const kLGAutoPkgRecipePathKey;
extern NSString *const kLGAutoPkgRepoKey;
extern NSString *const kLGAutoPkgRepoPathKey;

@interface LGAutoPkgTask : NSObject

@property (copy, nonatomic) NSArray *arguments;

/**
 *  The block to use for providing run status updates asynchronously. 
 */
@property (copy) void (^runStatusUpdate)(NSString *message, double progress);
@property (copy, nonatomic, readonly) NSString *standardOutString;
@property (copy, nonatomic, readonly) NSString *standardErrString;

/**
 * An array of dictionaries based on the autopkg verb
 * @discussion only, recipe-list, repo-list, and search will return values, all others will return nil;
 */
@property (copy, nonatomic, readonly) NSArray *results;

/**
 *  Observable KVO property indicating the task has completed.
 */
@property (nonatomic, readonly) BOOL complete;

- (BOOL)launch:(NSError **)error;
- (void)launchInBackground:(void (^)(NSError *error))reply;

- (BOOL)cancel:(NSError **)error;

#pragma mark - Class Methods
#pragma mark-- Run methods
+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *message, double taskProgress))progress
                reply:(void (^)(NSDictionary *report, NSError *error))reply;

+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *message))progress
             reply:(void (^)(NSError *error))reply;

+ (void)search:(NSString *)recipe
         reply:(void (^)(NSArray *results, NSError *error))reply;

+ (void)makeOverride:(NSString *)recipe
               reply:(void (^)(NSError *error))reply;

+ (void)listRecipes:(void (^)(NSArray *recipes, NSError *error))reply;
+ (NSArray *)listRecipes;

#pragma mark-- Repo methods
+ (void)repoAdd:(NSString *)repo
          reply:(void (^)(NSError *error))reply;

+ (void)repoRemove:(NSString *)repo
             reply:(void (^)(NSError *error))reply;

+ (void)repoUpdate:(void (^)(NSError *error))reply;

+ (void)repoList:(void (^)(NSArray *repos, NSError *error))reply;

#pragma mark-- Other
+ (NSString *)version;

@end
