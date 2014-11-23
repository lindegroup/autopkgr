//
//  LGApplications.h
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

#import <Foundation/Foundation.h>
#import "LGAutoPkgTask.h"
#import "LGTableView.h"

@interface LGRecipes : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (copy,nonatomic) NSArray *recipes;
@property (copy,nonatomic) NSArray *activeRecipes;
@property (copy,nonatomic) NSArray *searchedRecipes;
@property (weak) IBOutlet LGTableView *recipeTableView;
@property (weak) IBOutlet NSSearchField *recipeSearchField;

+ (NSString *)recipeList;

- (void)reload;
- (void)writeRecipeList;
- (NSMenu *)contextualMenuForRecipeAtRow:(NSInteger)row;

@end
