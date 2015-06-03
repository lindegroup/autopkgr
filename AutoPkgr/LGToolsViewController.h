//
//  LGToolsViewController.h
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

#import <Cocoa/Cocoa.h>
#import "LGBaseTabViewController.h"
#import "LGJSSImporter.h"

@class LGToolManager;

@interface LGToolsViewController : LGBaseTabViewController

@property (strong) LGToolManager *toolManager;

@property (weak) IBOutlet NSTextField *localMunkiRepo;
@property (weak) IBOutlet NSTextField *autoPkgRecipeRepoDir;
@property (weak) IBOutlet NSTextField *autoPkgCacheDir;
@property (weak) IBOutlet NSTextField *autoPkgRecipeOverridesDir;

- (void)enableFolders;

// Buttons
@property (weak) IBOutlet NSButton *openLocalMunkiRepoFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgRecipeReposFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgCacheFolderButton;
@property (weak) IBOutlet NSButton *openAutoPkgRecipeOverridesFolderButton;

@property (weak) IBOutlet LGJSSImporter *jssImporter;

- (IBAction)openLocalMunkiRepoFolder:(id)sender;
- (IBAction)openAutoPkgRecipeReposFolder:(id)sender;
- (IBAction)openAutoPkgCacheFolder:(id)sender;
- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender;

- (IBAction)chooseLocalMunkiRepo:(id)sender;
- (IBAction)chooseAutoPkgCacheDir:(id)sender;
- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender;

@end
