//
//  LGDefaults.m
//  AutoPkgr
//
//  Created by Eldon on 8/5/14.
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

#import "LGDefaults.h"

@implementation LGDefaults
+ (BOOL)fixRelativePathsInAutoPkgDefaults
{
    NSUserDefaults *autoPkgDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.github.autopkg"];
    NSString *recipeRepoDir = [autoPkgDefaults objectForKey:@"RECIPE_REPO_DIR"];
    NSDictionary *recipeRepos = [autoPkgDefaults objectForKey:@"RECIPE_REPOS"];
    NSArray *recipeSearchDirs = [autoPkgDefaults objectForKey:@"RECIPE_SEARCH_DIRS"];
    BOOL neededFixing = NO;
    if ([[recipeRepoDir pathComponents].firstObject isEqualToString:@"~"]) {
        [autoPkgDefaults setObject:[recipeRepoDir stringByExpandingTildeInPath] forKey:@"RECIPE_REPO_DIR"];
        neededFixing = YES;
    }

    NSMutableArray *newRecipeSearchDirs = [NSMutableArray new];
    for (NSString *dir in recipeSearchDirs) {
        if ([[dir pathComponents].firstObject isEqualToString:@"~"]) {
            [newRecipeSearchDirs addObject:[dir stringByExpandingTildeInPath]];
            neededFixing = YES;
        } else if ([dir length] > 1 && [[dir substringToIndex:2] isEqualToString:@"/~"]) {
            [newRecipeSearchDirs addObject:[[dir substringFromIndex:1] stringByExpandingTildeInPath]];
            neededFixing = YES;
        } else {
            [newRecipeSearchDirs addObject:dir];
        }
    }
    [autoPkgDefaults setObject:newRecipeSearchDirs forKey:@"RECIPE_SEARCH_DIRS"];

    // use this here instead of block enumeration because
    // this should finish before anything else occurs...
    NSMutableDictionary *newRecipeRepos = [NSMutableDictionary new];
    for (NSString *key in [recipeRepos allKeys]) {
        if ([[key pathComponents].firstObject isEqualToString:@"~"]) {
            [newRecipeRepos setObject:recipeRepos[key] forKey:[key stringByExpandingTildeInPath]];
            neededFixing = YES;
        } else if ([key length] > 1 && [[key substringToIndex:2] isEqualToString:@"/~"]) {
            [newRecipeRepos setObject:recipeRepos[key] forKey:[[key substringFromIndex:1] stringByExpandingTildeInPath]];
            neededFixing = YES;
        } else {
            [newRecipeRepos setObject:recipeRepos[key] forKey:key];
        }
    }
    [autoPkgDefaults setObject:newRecipeRepos forKey:@"RECIPE_REPOS"];
    [autoPkgDefaults synchronize];
    return neededFixing;
}

@end
