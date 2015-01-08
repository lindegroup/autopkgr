//
//  LGPopularRepositories.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/9/14.
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

#import "LGPopularRepositories.h"
#import "LGAutoPkgr.h"
#import "LGRecipeSearch.h"

@implementation LGPopularRepositories{
    LGRecipeSearch *_searchPanel;
}

- (id)init
{
    self = [super init];

    if (self) {
        _awake = NO;
        _jsonLoader = [[LGGitHubJSONLoader alloc] init];

        NSArray *recipeRepos = [_jsonLoader getAutoPkgRecipeRepos];

        if (recipeRepos != nil) {
            _popularRepos = [recipeRepos arrayByAddingObject:kLGJSSDefaultRepo];
        } else {
            _popularRepos = @[ @"https://github.com/autopkg/recipes.git",
                               @"https://github.com/autopkg/keeleysam-recipes.git",
                               @"https://github.com/autopkg/hjuutilainen-recipes.git",
                               @"https://github.com/autopkg/timsutton-recipes.git",
                               @"https://github.com/autopkg/nmcspadden-recipes.git",
                               @"https://github.com/autopkg/jleggat-recipes.git",
                               @"https://github.com/autopkg/jaharmi-recipes.git",
                               @"https://github.com/autopkg/jessepeterson-recipes.git",
                               @"https://github.com/autopkg/dankeller-recipes.git",
                               @"https://github.com/autopkg/hansen-m-recipes.git",
                               @"https://github.com/autopkg/scriptingosx-recipes.git",
                               @"https://github.com/autopkg/derak-recipes.git",
                               @"https://github.com/autopkg/sheagcraig-recipes.git",
                               @"https://github.com/autopkg/arubdesu-recipes.git",
                               @"https://github.com/autopkg/jps3-recipes.git",
                               @"https://github.com/autopkg/joshua-d-miller-recipes.git",
                               @"https://github.com/autopkg/gerardkok-recipes.git",
                               @"https://github.com/autopkg/swy-recipes.git",
                               @"https://github.com/autopkg/lashomb-recipes.git",
                               @"https://github.com/autopkg/rustymyers-recipes.git",
                               @"https://github.com/autopkg/luisgiraldo-recipes.git",
                               @"https://github.com/autopkg/justinrummel-recipes.git",
                               @"https://github.com/autopkg/n8felton-recipes.git",
                               @"https://github.com/autopkg/groob-recipes.git",
                               @"https://github.com/autopkg/jazzace-recipes.git",
                               kLGJSSDefaultRepo];
        }

        [self assembleRepos];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reload)
                                                     name:kLGNotificationReposModified
                                                   object:nil];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)repoEditDidEndWithError:(NSError *)error withTableView:(NSTableView *)tableView
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _activeRepos = [LGAutoPkgTask repoList];
        [_recipesObject reload];
        [tableView reloadData];
        [_progressDelegate stopProgress:error];
    }];
}

- (void)reload
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self assembleRepos];
        [_recipesObject reload];
    }];
}

- (void)assembleRepos
{
    _activeRepos = [LGAutoPkgTask repoList];
    NSMutableArray *workingPR = [_popularRepos mutableCopy];
    for (NSDictionary *dict in _activeRepos) {
        if (![workingPR containsObject:dict[kLGAutoPkgRepoURLKey]]) {
            [workingPR addObject:dict[kLGAutoPkgRepoURLKey]];
        }
    }

    _popularRepos = [workingPR copy];
    [self executeRepoSearch:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRepos count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        NSString *repo = [_searchedRepos objectAtIndex:row];
        NSPredicate *repoPred = [NSPredicate predicateWithFormat:@"%K == %@",kLGAutoPkgRepoURLKey, repo];
        return @([[_activeRepos filteredArrayUsingPredicate:repoPred] count] != 0);
    } else if ([[tableColumn identifier] isEqualToString:@"repoURL"]) {
        return [_searchedRepos objectAtIndex:row];
    }
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        NSString *repo = [_searchedRepos objectAtIndex:row];
        BOOL add = [object isEqual:@YES];
        NSString *message = [NSString stringWithFormat:@"%@ %@", add ? @"Adding" : @"Removing", repo];
        NSLog(@"%@", message);
        [_progressDelegate startProgressWithMessage:message];
        if (add) {
            [LGAutoPkgTask repoAdd:repo reply:^(NSError *error) {
                [self repoEditDidEndWithError:error withTableView:tableView];
            }];
        } else {
            [LGAutoPkgTask repoRemove:repo reply:^(NSError *error) {
                [self repoEditDidEndWithError:error withTableView:tableView];
            }];
        }
    }
}

- (void)executeRepoSearch:(id)sender
{
    if (_awake == NO) {
        _searchedRepos = [NSArray arrayWithArray:_popularRepos];
        return;
    }

    [_popularRepositoriesTableView beginUpdates];
    [_popularRepositoriesTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];

    if ([[_repoSearch stringValue] isEqualToString:@""]) {
        _searchedRepos = _popularRepos;
    } else {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[CD] %@",[_repoSearch stringValue]];
        _searchedRepos = [_popularRepos filteredArrayUsingPredicate:searchPredicate];
    }

    [_popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [_popularRepositoriesTableView endUpdates];
}

- (void)awakeFromNib
{
    _awake = YES;
    [_repoSearch setTarget:self];
    [_repoSearch setAction:@selector(executeRepoSearch:)];
}

#pragma mark - Class Methods
+ (NSMenu *)contextualMenuForRepo:(NSString *)repo
{
    return nil;

    // TODO: Eventually this could be setup for something
    // The AutoPkgTask repo-list needs to be reworked to send back an array of dicts.
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Reveal in Finder"
                                                  action:nil keyEquivalent:@""];
    [menu addItem:item];
    return menu;
}

#pragma mark - Search Panel
- (IBAction)openSearchPanel:(id)sender
{
    if (!_searchPanel) {
        _searchPanel = [[LGRecipeSearch alloc] init];
    }
    
    [NSApp beginSheet:_searchPanel.window
       modalForWindow:self.modalWindow
        modalDelegate:self
       didEndSelector:@selector(didCloseSearchPanel)
          contextInfo:NULL];
}

- (void)didCloseSearchPanel{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_searchPanel.window close];
        _searchPanel = nil;
        [self reload];
    }];
}

@end
