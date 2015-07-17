//
//  LGRecipeReposViewController.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
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

#import <Cocoa/Cocoa.h>
#import "LGTabViewControllerBase.h"

@class LGRepoTableViewController, LGRecipeTableViewController;

@interface LGRecipeReposViewController : LGTabViewControllerBase

// Objects
@property (strong) IBOutlet LGRepoTableViewController *popRepoTableViewHandler;
@property (strong) IBOutlet LGRecipeTableViewController *recipeTableViewHandler;


@property (weak) IBOutlet NSButton *runAutoPkgNowButton;
@property (weak) IBOutlet NSButton *updateRepoNowButton;
@property (weak, nonatomic) NSButton *cancelButton;

- (IBAction)updateReposNow:(id)sender;
- (IBAction)checkAppsNow:(id)sender;
- (void)cancelAutoPkgRun:(id)sender;

- (IBAction)addAutoPkgRepoURL:(id)sender;

@end
