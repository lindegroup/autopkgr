//
//  LGAutoPkgRunner.h
//  AutoPkgr
//
//  Created by James Barclay on 7/1/14.
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
#import "LGEmailer.h"

@interface LGAutoPkgRunner : NSObject
@property (strong, nonatomic) LGEmailer *emailer;

- (NSArray *)getLocalAutoPkgRecipes;
- (NSArray *)getLocalAutoPkgRecipeRepos;
- (void)addAutoPkgRecipeRepo:(NSString *)repoURL;
- (void)removeAutoPkgRecipeRepo:(NSString *)repoURL;
- (void)updateAutoPkgRecipeRepos;
- (void)runAutoPkgWithRecipeListAndSendEmailNotificationIfConfigured:(NSString *)recipeListPath;
- (void)sendNewDowloadsEmail:(NSArray *)newDownloadsArray;
- (void)invokeAutoPkgInBackgroundThread;
- (void)invokeAutoPkgRepoUpdateInBackgroundThread;
- (void)runAutoPkgWithRecipeList;
- (void)setLocalMunkiRepoForAutoPkg:(NSString *)localMunkiRepo;

@end
