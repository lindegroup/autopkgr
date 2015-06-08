//
//  LGRepoTableViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/3/2015.
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGRepoTableViewController.h"
#import "LGTableCellViews.h"
#import "LGAutoPkgr.h"
#import "LGRecipeSearch.h"
#import "LGAutoPkgRepo.h"
#import "LGAutoPkgTask.h"
#import "LGGitHubJSONLoader.h"

@interface LGRepoTableViewController ()

@property (copy, nonatomic) NSArray *repos;
@property (copy, nonatomic) NSMutableArray *searchedRepos;

@property (weak) IBOutlet LGTableView *popularRepositoriesTableView;
@property (weak) IBOutlet NSSearchField *repoSearch;

@end

@implementation LGRepoTableViewController {
    LGRecipeSearch *_searchPanel;

    BOOL _awake;
    BOOL _updateRepoInternally;
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
        [LGAutoPkgRepo commonRepos:^(NSArray *repos) {
            NSArray *sortDescriptors = nil;
            if (_popularRepositoriesTableView.sortDescriptors.count) {
                sortDescriptors = _popularRepositoriesTableView.sortDescriptors;
            } else {
                sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:NSStringFromSelector(@selector(stars))
                                                                  ascending:NO]];
            }

            _repos = [repos sortedArrayUsingDescriptors:sortDescriptors];

            [self executeRepoSearch:nil];
        }];
    }
    _updateRepoInternally = NO;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchedRepos count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    LGAutoPkgRepo *repo = [_searchedRepos objectAtIndex:row];
    LGRepoStatusCellView *statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

    if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(isInstalled))]) {
        statusCell.enabledCheckBox.state = repo.isInstalled;
        statusCell.enabledCheckBox.tag = row;
        statusCell.enabledCheckBox.action = @selector(enableRepo:);
        statusCell.enabledCheckBox.target = self;

    } else if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(cloneURL))]) {
        statusCell.textField.stringValue = repo.cloneURL.absoluteString;
    } else if ([[tableColumn identifier] isEqualToString:NSStringFromSelector(@selector(stars))]) {
        if (repo.homeURL && (repo.stars > 0)) {
            // u2650 is the star symbol.
            statusCell.textField.stringValue = [@"\u2605 " stringByAppendingString:@(repo.stars).stringValue];
        } else {
            statusCell.textField.stringValue = @"";
        }
    } else if ([[tableColumn identifier] isEqualToString:@"status"]) {
        statusCell.imageView.hidden = YES;

        repo.statusChangeBlock = ^(LGAutoPkgRepoStatus status) {
            [statusCell.progressIndicator stopAnimation:self];
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

    BOOL add = sender.state;
    LGAutoPkgRepo *repo = _searchedRepos[sender.tag];

    NSString *message = [NSString stringWithFormat:@"%@ %@", add ? @"Adding" : @"Removing", repo.cloneURL];
    NSLog(@"%@", message);
    [_progressDelegate startProgressWithMessage:message];
    if (add) {
        [repo install:^(NSError *error) {
            [_progressDelegate stopProgress:error];
        }];
    } else {
        [repo remove:^(NSError *error) {
            [_progressDelegate stopProgress:error];
        }];
    }
}

- (void)updateRepo:(id)sender
{
    _updateRepoInternally = YES;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        LGAutoPkgRepo *repo = [sender representedObject];
        [_progressDelegate startProgressWithMessage:@"Updating"];
        [repo updateRepo:^(NSError *error) {
            [_progressDelegate stopProgress:error];
        }];
    }
}

- (void)executeRepoSearch:(id)sender
{
    [_popularRepositoriesTableView beginUpdates];
    [_popularRepositoriesTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];

    if (_repoSearch.stringValue.length == 0) {
        _searchedRepos = [_repos mutableCopy];
    } else {
        NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"%K.absoluteString CONTAINS[CD] %@", NSStringFromSelector(@selector(cloneURL)), _repoSearch.stringValue];
        _searchedRepos = [[_repos filteredArrayUsingPredicate:searchPredicate] mutableCopy];
    }

    [_popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [_popularRepositoriesTableView endUpdates];
}

- (NSMenu *)contextualMenuForRow:(NSInteger)row
{

    LGAutoPkgRepo *repo = _searchedRepos[row];
    NSMenu *menu = [[NSMenu alloc] init];

    // Update Repo...
    NSMenuItem *updateItem = [[NSMenuItem alloc] initWithTitle:@"Update Repo"
                                                        action:@selector(updateRepo:)
                                                 keyEquivalent:@""];
    updateItem.target = self;
    updateItem.representedObject = repo;

    [menu addItem:updateItem];

    // Commits ...
    if (repo.commitsURL) {
        NSMenuItem *commitsItem = [[NSMenuItem alloc] initWithTitle:@"Open Commits Page"
                                                             action:@selector(viewCommitsOnGitHub:)
                                                      keyEquivalent:@""];
        commitsItem.target = repo;
        [menu addItem:commitsItem];
    }

    if (repo.path) {
        NSMenuItem *clipboardItem = [[NSMenuItem alloc] initWithTitle:@"Copy path to clipboard"
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
        [[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
        [[NSPasteboard generalPasteboard] setString:string forType:NSStringPboardType];
    }
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

- (void)didCloseSearchPanel
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_searchPanel.window close];
        _searchPanel = nil;
        [self reload];
    }];
}

@end
