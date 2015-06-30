//
//  LGRecipeReposViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
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
//  limitations under the License.//

#import "LGRecipeReposViewController.h"
#import "LGAutoPkgTask.h"
#import "LGRecipeTableViewController.h"
#import "LGRepoTableViewController.h"

@interface LGRecipeReposViewController ()<NSTextFieldDelegate>
@property (weak) IBOutlet NSTextField *repoURLToAdd;
@property (weak) IBOutlet NSButton *addRepoButton;

@end

@implementation LGRecipeReposViewController
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

- (IBAction)addAutoPkgRepoURL:(id)sender
{
    NSString *repo = [_repoURLToAdd stringValue];
    [self.progressDelegate startProgressWithMessage:[NSString stringWithFormat:@"Adding %@", repo]];

    [LGAutoPkgTask repoAdd:repo reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressDelegate stopProgress:error];
        }];
    }];
    [_repoURLToAdd setStringValue:@""];
}

- (void)controlTextDidChange:(NSNotification *)note {
    if([note.object isEqualTo:_repoURLToAdd]){
        NSString *url = [note.object stringValue];
        _addRepoButton.enabled = [url hasPrefix:@"http"];
    }
}

@end
