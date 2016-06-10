//
//  LGRepoTableViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/3/2015.
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

#import "LGAutoPkgRepo.h"
#import "LGAutoPkgTask.h"
#import "LGAutoPkgr.h"
#import "LGGitHubJSONLoader.h"
#import "LGRecipeSearch.h"
#import "LGRepoTableViewController.h"
#import "LGTableCellViews.h"

@interface LGRepoTableViewController ()

@property (copy, nonatomic, readwrite) NSArray *repos;
@property (copy, nonatomic) NSMutableArray *searchedRepos;

@property (weak) IBOutlet LGTableView *popularRepositoriesTableView;
@property (weak) IBOutlet NSSearchField *repoSearch;

@end

@implementation LGRepoTableViewController {
    BOOL _awake;
    BOOL _updateRepoInternally;
    BOOL _fetchingRepoData;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    if (!_awake) {
        _awake = YES;
        [_repoSearch setTarget:self];
        [_repoSearch setAction:@selector(executeRepoSearch:)];

        [self reload];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload) name:kLGNotificationReposModified object:nil];
    }
}

- (void)reload
{
    if (!_updateRepoInternally) {
        _fetchingRepoData = YES;
        [LGAutoPkgRepo commonRepos:^(NSArray *repos) {
            NSArray *sortDescriptors = nil;
            if (self.popularRepositoriesTableView.sortDescriptors.count) {
                sortDescriptors = self.popularRepositoriesTableView.sortDescriptors;
            }
            else {
                sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(stars))
                                                                   ascending:NO] ];
            }

            _repos = [repos sortedArrayUsingDescriptors:sortDescriptors];
            _fetchingRepoData = NO;
            [self executeRepoSearch:nil];
        }];
    }
    _updateRepoInternally = NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _fetchingRepoData ? 1 : _searchedRepos.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    LGRepoStatusCellView *statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

    if (_fetchingRepoData) {
        if ([tableColumn.identifier isEqualToString:NSStringFromSelector(@selector(cloneURL))]) {
            statusCell.textField.stringValue = @"Fetching remote data...";
        }
        else if ([[tableColumn identifier] isEqualToString:@"status"]) {
            [statusCell.progressIndicator startAnimation:self];
        }
        return statusCell;
    }

    LGAutoPkgRepo *repo = [_searchedRepos objectAtIndex:row];
    if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(isInstalled))]) {
        statusCell.enabledCheckBox.state = repo.isInstalled;
        statusCell.enabledCheckBox.tag = row;
        statusCell.enabledCheckBox.action = @selector(enableRepo:);
        statusCell.enabledCheckBox.target = self;
    }
    else if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(cloneURL))]) {
        NSString *cloneURL = repo.cloneURL.absoluteString;
        if (cloneURL) {
            statusCell.textField.stringValue = repo.cloneURL.absoluteString;
        }
        else {
            statusCell.textField.placeholderString = @"<Could not find clone URL>";
        }
    }
    else if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(stars))]) {
        if (repo.homeURL && (repo.stars > 0)) {
            // u2650 is the star symbol.
            statusCell.textField.stringValue = [@"\u2605 " stringByAppendingString:@(repo.stars).stringValue];
        }
        else {
            statusCell.textField.stringValue = @"";
        }
    }
    else if ([[tableColumn identifier] isEqualToString:@"status"]) {
        statusCell.imageView.hidden = YES;
        repo.statusChangeBlock = ^(LGAutoPkgRepoStatus status) {
            switch (status) {
            case kLGAutoPkgRepoNotInstalled: {
                statusCell.imageView.hidden = YES;
                break;
            }
            case kLGAutoPkgRepoUpdateAvailable: {
                statusCell.imageView.image = [NSImage LGStatusUpdateAvailable];
                statusCell.imageView.hidden = NO;
                break;
            }
            case kLGAutoPkgRepoUpToDate: {
                statusCell.imageView.image = [NSImage LGStatusUpToDate];
                statusCell.imageView.hidden = NO;
                break;
            }
            }
            [statusCell.progressIndicator stopAnimation:self];
        };

        if (repo.isInstalled) {
            [statusCell.progressIndicator startAnimation:self];
            statusCell.imageView.image = [NSImage LGStatusUpdateAvailable];
        }
        // Calling checkRepoStatus will execute the repo.statusChangeBlock.
        [repo checkRepoStatus:nil];
    }
    return statusCell;
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    [_searchedRepos sortUsingDescriptors:tableView.sortDescriptors];
    [tableView reloadData];
}

- (void)enableRepo:(NSButton *)sender
{
    _updateRepoInternally = YES;

    /* The button's tag is set to the row in 
     * the tableView:viewForTableColumn:row: */
    NSInteger row = sender.tag;
    BOOL add = sender.state;

    LGAutoPkgRepo *repo = _searchedRepos[row];

    void (^repoModified)(NSError *error) = ^void(NSError *error) {
        [_progressDelegate stopProgress:error];
        if (error) {
            sender.state = !sender.state;
        }
    };

    NSString *message = [NSString stringWithFormat:@"%@ %@...", add ? @"Adding" : @"Removing", repo.cloneURL];

    NSLog(@"%@", message);
    [_progressDelegate startProgressWithMessage:message];
    if (add) {
        [repo install:repoModified];
    }
    else {
        [repo remove:repoModified];
    }
}

- (void)updateRepo:(id)sender
{
    _updateRepoInternally = YES;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        LGAutoPkgRepo *repo = [sender representedObject];
        NSString *message = [NSString stringWithFormat:@"Updating %@...", repo.cloneURL];

        [_progressDelegate startProgressWithMessage:message];
        [repo update:^(NSError *error) {
            [_progressDelegate stopProgress:error];
        }];
    }
}

- (void)executeRepoSearch:(id)sender
{
    [_popularRepositoriesTableView beginUpdates];

    [_popularRepositoriesTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _popularRepositoriesTableView.numberOfRows)] withAnimation:NSTableViewAnimationEffectNone];

    if (_repoSearch.stringValue.length == 0) {
        _searchedRepos = [_repos mutableCopy];
    }
    else {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"%K.absoluteString CONTAINS[CD] %@", NSStringFromSelector(@selector(cloneURL)), _repoSearch.stringValue];
        _searchedRepos = [[_repos filteredArrayUsingPredicate:searchPredicate] mutableCopy];
    }

    [_popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [_popularRepositoriesTableView endUpdates];
}

/**
 *  This will add or remove an array of recipe repos. The LGAuotPkg task args are created while building the contextual menu.
 *
 *  @param sender The contextual menu item sending the request.
 */

- (void)bulkModifyRecipeRepos:(NSMenuItem *)sender
{
    NSArray *taskArgs = sender.representedObject;

    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = taskArgs;

    [task setProgressUpdateBlock:^(NSString *message, double progress) {
        [_progressDelegate updateProgress:message progress:progress];
    }];

    NSInteger count = (taskArgs.count - 1);
    NSString *action = nil;
    if ([taskArgs.firstObject isEqualToString:@"repo-add"]) {
        action = @"Adding";
    }
    else if ([taskArgs.firstObject isEqualToString:@"repo-delete"]) {
        action = @"Removing";
    }
    else if ([taskArgs.firstObject isEqualToString:@"repo-update"]) {
        action = @"Updating";
    }

    if (action) {
        NSString *message = quick_formatString(@"%@ %ld recipe repo%@.", action, count, count > 1 ? @"s" : @"");
        [_progressDelegate startProgressWithMessage:message];
        [task launchInBackground:^(NSError *error) {
            [_progressDelegate stopProgress:error];
        }];
    }
}

- (NSMenu *)contextualMenuForRow:(NSInteger)row
{
    NSMenu *menu = [[NSMenu alloc] init];

    // Update repo.
    NSIndexSet *set = _popularRepositoriesTableView.selectedRowIndexes;

    if (set.count > 1) {
        /* Create the Add/Remove Repos menu. We construct the full args that are passed into the AutoPkg task.
         * With both repo-add and repo-delete, multiple repos can be passed in, so start with the command
         * and append the recipes that are considered. That is the array ultimately set as the menu item's
         * represented object. */
        __block NSMutableArray *update = @[ @"repo-update" ].mutableCopy,
                               *enabled = @[ @"repo-delete" ].mutableCopy,
                               *disabled = @[ @"repo-add" ].mutableCopy;

        [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            LGRepoStatusCellView *cell = [_popularRepositoriesTableView viewAtColumn:0 row:idx makeIfNecessary:NO];
            if (cell) {
                if (cell.enabledCheckBox.state) {
                    [update addObject:[_searchedRepos[idx] path]];
                    [enabled addObject:[_searchedRepos[idx] cloneURL].absoluteString];
                }
                else {
                    [disabled addObject:[_searchedRepos[idx] cloneURL].absoluteString];
                }
            }
        }];

        [@[ update, enabled, disabled ] enumerateObjectsUsingBlock:^(NSArray *array, NSUInteger idx, BOOL *stop) {
            if (array.count > 1) {
                NSString *title = [[NSString stringWithFormat:@"%@ selected repos",
                                                              [[array.firstObject componentsSeparatedByString:@"-"] lastObject]] capitalizedString];

                NSMenuItem *updateReposItem = [[NSMenuItem alloc] initWithTitle:title
                                                                         action:@selector(bulkModifyRecipeRepos:)
                                                                  keyEquivalent:@""];
                updateReposItem.representedObject = array;
                updateReposItem.target = self;
                [menu addItem:updateReposItem];
            }
        }];

        return menu;
    }

    LGAutoPkgRepo *repo = _searchedRepos[row];
    if (repo.isInstalled) {
        NSMenuItem *updateItem = [[NSMenuItem alloc] initWithTitle:@"Update This Repo Only"
                                                            action:@selector(updateRepo:)
                                                     keyEquivalent:@""];
        updateItem.target = self;
        updateItem.representedObject = repo;

        [menu addItem:updateItem];
    }

    // Commits.
    if (repo.commitsURL) {
        NSMenuItem *commitsItem = [[NSMenuItem alloc] initWithTitle:@"Open GitHub Commits Page"
                                                             action:@selector(viewCommitsOnGitHub:)
                                                      keyEquivalent:@""];
        commitsItem.target = repo;
        [menu addItem:commitsItem];
    }

    if (repo.cloneURL) {
        NSMenuItem *cloneItem = [[NSMenuItem alloc] initWithTitle:@"Copy URL to Clipboard"
                                                           action:@selector(copyToPasteboard:)
                                                    keyEquivalent:@""];

        cloneItem.representedObject = repo.cloneURL.absoluteString;
        cloneItem.target = self;
        [menu addItem:cloneItem];
    }

    if (repo.path) {
        NSMenuItem *clipboardItem = [[NSMenuItem alloc] initWithTitle:@"Copy Path to Clipboard"
                                                               action:@selector(copyToPasteboard:)
                                                        keyEquivalent:@""];
        clipboardItem.representedObject = repo.path;
        clipboardItem.target = self;
        [menu addItem:clipboardItem];
    }

    return menu;
}

- (void)copyToPasteboard:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSString *string = [sender representedObject];
        [[NSPasteboard generalPasteboard] declareTypes:@[ NSStringPboardType ] owner:nil];
        [[NSPasteboard generalPasteboard] setString:string forType:NSStringPboardType];
    }
}

@end
