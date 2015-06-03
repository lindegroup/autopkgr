//
//  LGConfigurationWindowController.h
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
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

#import <Cocoa/Cocoa.h>
#import "LGProgressDelegate.h"

// Tab Views.
#import "LGInstallViewController.h"
#import "LGRecipeReposViewController.h"
#import "LGScheduleViewController.h"
#import "LGNotificationsViewController.h"
#import "LGToolsViewController.h"

@class LGRepoTableViewController, LGRecipeTableViewController;

@interface LGConfigurationWindowController : NSWindowController <NSWindowDelegate, NSTabViewDelegate, LGProgressDelegate>

-(instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate;


@property (strong, nonatomic) LGInstallViewController *installView;
@property (strong, nonatomic) LGRecipeReposViewController *recipeRepoView;
@property (strong, nonatomic) LGScheduleViewController *scheduleView;
@property (strong, nonatomic) LGNotificationsViewController *notificationView;
@property (strong, nonatomic) LGToolsViewController *toolsView;


@property (weak) IBOutlet NSButton *cancelAutoPkgRunButton;

// Progress panel
@property (weak) IBOutlet NSPanel *progressPanel;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *progressMessage;
@property (weak) IBOutlet NSTextField *progressDetailsMessage;


@end
