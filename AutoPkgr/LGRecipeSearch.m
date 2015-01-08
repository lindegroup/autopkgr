//
//  LGRecipeSearch.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 12/19/14.
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

#import "LGRecipeSearch.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgTask.h"
#import "LGRecipes.h"

@interface LGRecipeSearch () <NSTextViewDelegate>
@property (weak) IBOutlet NSTableView *searchTable;
@property (weak) IBOutlet NSButton *cancelBT;
@property (weak) IBOutlet NSButton *addBT;
@property (weak) IBOutlet NSSearchField *searchField;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *limitMessage;

@property (copy, nonatomic) NSArray *searchResults;
@property (copy, nonatomic) NSArray *currentlyInstalledRepos;

@end

@implementation LGRecipeSearch

#pragma mark - Init / Load
- (void)dealloc
{
    // On dealloc nil out the dataSource and delegate to prevent
    // KVO messages getting sent to the searchTable after
    // deallocation of the LGRecipeSearch object
    _searchTable.dataSource = nil;
    _searchTable.delegate = nil;
}

- (id)init
{
    return [self initWithWindowNibName:@"LGRecipeSearchPanel"];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    _progressIndicator.hidden = YES;
    _currentlyInstalledRepos = [LGAutoPkgTask repoList];
}

#pragma mark - IBActions
- (IBAction)searchNow:(NSSearchField *)sender
{
    NSString *searchString = sender.safeStringValue;
    if (searchString) {
        [_progressIndicator setHidden:NO];
        [_progressIndicator startAnimation:nil];

        [LGAutoPkgTask search:searchString
                        reply:^(NSArray *results, NSError *error) {
                            [_progressIndicator stopAnimation:nil];
                            [_progressIndicator setHidden:YES];
                            if (error) {
                                _limitMessage.hidden = NO;
                                NSLog(@"%@",error);
                            } else {
                                _limitMessage.hidden = YES;
                                _searchResults = results;
                                [_searchTable reloadData];
                            }
                        }];
    }
}

- (IBAction)addRecipeAndRepo:(NSButton *)sender
{
    NSString *repoName = _searchResults[_searchTable.selectedRow][kLGAutoPkgRepoNameKey];
    NSString *url = [NSString stringWithFormat:@"https://github.com/autopkg/%@.git", repoName];

    [_progressIndicator startAnimation:nil];
    [_progressIndicator setHidden:NO];

    [LGAutoPkgTask repoAdd:url reply:^(NSError *error) {
        [_progressIndicator stopAnimation:nil];
        [_progressIndicator setHidden:YES];
        if (error) {
            NSLog(@"%@", error.localizedDescription);
        } else {
            _currentlyInstalledRepos = [LGAutoPkgTask repoList];
            [_addBT setEnabled:NO];
            [_searchTable reloadData];
        }
    }];
}

- (IBAction)closePanel:(id)sender
{
    [NSApp endSheet:self.window];
}

#pragma mark - Table View Delegate / Data Source
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_searchResults count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (row < _searchResults.count) {
        if ([tableColumn.identifier isEqualToString:@"installed"]) {
            NSString *match = _searchResults[row][kLGAutoPkgRepoNameKey];
            NSPredicate *predicate = [self repoMatchPredicate:match];

            return ([_currentlyInstalledRepos filteredArrayUsingPredicate:predicate].count) ? [NSImage LGStatusAvailable] : [NSImage LGStatusNone];
        } else {
            return [[_searchResults objectAtIndex:row] objectForKey:[tableColumn identifier]];
        }
    }
    return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [notification.object selectedRow];
    if (row < _searchResults.count && row > -1) {
        NSString *match = _searchResults[row][kLGAutoPkgRepoNameKey];
        NSPredicate *predicate = [self repoMatchPredicate:match];

        if ([_currentlyInstalledRepos filteredArrayUsingPredicate:predicate].count) {
            [_addBT setEnabled:NO];
        } else {
            [_addBT setEnabled:YES];
        }
    }
}

#pragma mark - Text View Delegate
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    // Though a subclass of NSTextField, the NSSearchField isn't respecting
    // "Send on enter only" set in the XIB, or even programatically , so we're
    //  using the TextView delegate here to do force that behavior.
    if ([notification.object isEqualTo:_searchField]) {
        if ([notification.userInfo[@"NSTextMovement"] intValue] == NSReturnTextMovement) {
            [self searchNow:notification.object];
        }
    }
}

#pragma mark - Utility
- (NSPredicate *)repoMatchPredicate:(NSString *)match
{
    return [NSPredicate predicateWithFormat:@"%K.lastPathComponent == %@", kLGAutoPkgRepoURLKey, [match stringByAppendingPathExtension:@"git"]];
}

@end
