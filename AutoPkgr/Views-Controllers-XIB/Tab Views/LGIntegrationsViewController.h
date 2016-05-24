//
//  LGIntegrationsViewController.h
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

#import <Cocoa/Cocoa.h>
#import "LGTabViewControllerBase.h"

@class LGIntegrationManager;

@interface LGIntegrationsViewController : LGTabViewControllerBase <NSWindowDelegate>

@property (strong) LGIntegrationManager *integrationManager;
@property (strong) NSWindow *configurationWindow;

- (void)enableFolders;

#pragma mark - AutoPkg
#pragma mark -- Repo Dir --
@property (weak) IBOutlet NSButton *openAutoPkgRecipeReposFolderButton;
@property (weak) IBOutlet NSTextField *autoPkgRecipeRepoDir;
- (IBAction)openAutoPkgRecipeReposFolder:(id)sender;
- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender;

#pragma mark -- Cache Dir --
@property (weak) IBOutlet NSButton *openAutoPkgCacheFolderButton;
@property (weak) IBOutlet NSTextField *autoPkgCacheDir;
- (IBAction)openAutoPkgCacheFolder:(id)sender;
- (IBAction)chooseAutoPkgCacheDir:(id)sender;

#pragma mark -- Overrides Dir --
@property (weak) IBOutlet NSButton *openAutoPkgRecipeOverridesFolderButton;
@property (weak) IBOutlet NSTextField *autoPkgRecipeOverridesDir;
- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender;
- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender;

@end
