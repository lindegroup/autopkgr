//
//  LGPopularRepositories.h
//  AutoPkgr
//
//  Created by Josh Senick on 7/9/14.
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
#import "LGGitHubJSONLoader.h"
#import "LGRecipes.h"
#import "LGProgressDelegate.h"

@interface LGPopularRepositories : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource> {

    NSArray *_popularRepos;
    NSArray *_activeRepos;
    NSArray *_searchedRepos;
    LGGitHubJSONLoader *_jsonLoader;
    BOOL _awake;
}

+ (NSMenu *)contextualMenuForRepo:(NSString *)repo;
- (void)reload;

@property (weak) IBOutlet NSWindow *modalWindow;

@property (weak) IBOutlet LGTableView *popularRepositoriesTableView;
@property (weak) IBOutlet NSSearchField *repoSearch;
@property (weak) id<LGProgressDelegate> progressDelegate;

@end
