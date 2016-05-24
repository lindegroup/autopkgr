//
//  LGRecipeReposViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
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

#import "LGRecipeReposViewController.h"
#import "LGRecipeTableViewController.h"
#import "LGRepoTableViewController.h"
#import "LGAutoPkgTask.h"
#import "LGAutoPkgRepo.h"
#import "LGAutoPkgRecipe.h"
#import "LGRecipeSearch.h"
#import "LGNotificationManager.h"

#import "NSTextField+animatedString.h"

@interface LGRecipeReposViewController ()<NSTextFieldDelegate>
@property (weak) IBOutlet NSTextField *repoURLToAdd;
@property (weak) IBOutlet NSButton *addRepoButton;

@property (weak) IBOutlet NSButton *recipeSearchButton;
@property (weak) IBOutlet NSTextField *recipeSearchTF;
@property (weak) IBOutlet NSTextField *recipeSearchResultsErrorTF;

@property (weak) IBOutlet NSProgressIndicator *searchProgressIndicator;
@property (weak) IBOutlet NSProgressIndicator *repoAddProgressIndicator;

@property (strong, nonatomic) LGAutoPkgTaskManager *taskManager;



@end

@implementation LGRecipeReposViewController {
    LGRecipeSearch *_searchPanel;
}

@synthesize modalWindow = _modalWindow;

- (instancetype)init
{
    return (self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil]);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    if (!self.awake) {
        self.awake = YES;
        _popRepoTableViewHandler.progressDelegate = self.progressDelegate;
        _repoURLToAdd.delegate = self;
        _addRepoButton.enabled = NO;

        _recipeSearchTF.delegate = self;
        _recipeSearchButton.enabled = NO;
    }
}

- (void)setModalWindow:(NSWindow *)modalWindow
{
    _modalWindow = modalWindow;
    _popRepoTableViewHandler.modalWindow = modalWindow;
}

- (NSString *)tabLabel
{
    return NSLocalizedString(@"Repos & Recipes", @"Tab label");
}

#pragma mark - AutoPkg actions
- (void)setCancelButton:(NSButton *)cancelButton
{
    _cancelButton = cancelButton;
    _cancelButton.action = @selector(cancelAutoPkgRun:);
    _cancelButton.target = self;
}

- (IBAction)updateReposNow:(id)sender
{
    _cancelButton.hidden = NO;
    [self.progressDelegate startProgressWithMessage:NSLocalizedString(@"Updating AutoPkg recipe repos.",
                                                                      @"Progress panel message when updating repos.")];

    [_updateRepoNowButton setEnabled:NO];
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }
    _taskManager.progressDelegate = self.progressDelegate;

    [_taskManager repoUpdate:^(NSError *error) {
        NSAssert([NSThread isMainThread], @"Reply not on main thread!");
        [self.progressDelegate stopProgress:error];
        _updateRepoNowButton.enabled = YES;
    }];
}

- (IBAction)checkAppsNow:(id)sender
{
    NSString *recipeList = [LGAutoPkgRecipe defaultRecipeList];
    _cancelButton.hidden = NO;
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }
    _taskManager.progressDelegate = self.progressDelegate;

    [self.progressDelegate startProgressWithMessage:NSLocalizedString(@"Running selected AutoPkg recipes...",
                                                                      @"Progress panel message when running recipes.")];

    [_taskManager runRecipeList:recipeList
                         updateRepo:NO
                              reply:^(NSDictionary *report, NSError *error) {
                                  NSAssert([NSThread isMainThread], @"Reply not on main thread!");
                                  [self.progressDelegate stopProgress:error];
                                  LGNotificationManager *notifier = [[LGNotificationManager alloc]
                                                                     initWithReportDictionary:report errors:error];

                                  [notifier sendEnabledNotifications:^(NSError *error) {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          [self.progressDelegate stopProgress:error];
                                      });
                                  }];
                              }];
}

- (IBAction)cancelAutoPkgRun:(id)sender
{
    if (_taskManager) {
        [_taskManager cancel];
    }
}

- (IBAction)addAutoPkgRepoURL:(id)sender
{
    NSString *cloneURL = [_repoURLToAdd stringValue];
    [self.progressDelegate startProgressWithMessage:[NSString stringWithFormat:@"Adding %@", cloneURL]];

    LGAutoPkgRepo *repo = [[LGAutoPkgRepo alloc] initWithCloneURL:cloneURL];
    [repo install:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressDelegate stopProgress:error];
        }];
    }];

    [_repoURLToAdd setStringValue:@""];
}

#pragma mark - Search Panel
- (IBAction)openSearchPanel:(NSButton *)sender
{
    NSString *origTitle = sender.title;
    
    sender.enabled = NO;
    sender.title = @"Searching...";

    [_searchProgressIndicator startAnimation:self];
    [_searchProgressIndicator setDoubleValue:25.0];

    [LGAutoPkgTask search:_recipeSearchTF.stringValue reply:^(NSArray *results, NSError *error) {
        sender.enabled = YES;
        sender.title = origTitle;
        [_searchProgressIndicator setDoubleValue:100.0];

        if (results.count) {
            _searchPanel = [[LGRecipeSearch alloc] initWithSearchResults:results installedRepos:_popRepoTableViewHandler.repos];

            [_searchPanel openSheetOnWindow:self.modalWindow complete:^(LGWindowController *windowController) {
                _searchPanel = nil;
            }];
            
            [_searchProgressIndicator setDoubleValue:0.0];
            [_searchProgressIndicator stopAnimation:self];
            _searchProgressIndicator.hidden = YES;
        } else {
            [_recipeSearchResultsErrorTF fadeOut_withString:error.localizedDescription ?: @"No matching recipes found."];
        }
    }];
}

#pragma mark - Text delegate
- (void)controlTextDidChange:(NSNotification *)note {
    NSString *string = [note.object stringValue];

    if([note.object isEqualTo:_repoURLToAdd]){
        _addRepoButton.enabled = [LGAutoPkgRepo stringIsValidRepoURL:string];
    }

    else if([note.object isEqualTo:_recipeSearchTF]){
        _recipeSearchButton.enabled = string.length;
    }
}


@end
