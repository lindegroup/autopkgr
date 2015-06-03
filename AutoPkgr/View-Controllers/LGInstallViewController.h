//
//  LGInstallViewController.h
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
@class LGToolManager;

@interface LGInstallViewController : LGBaseTabViewController

@property (weak) IBOutlet NSButton *launchAtLoginButton;

// Display Mode settings
@property (weak) IBOutlet NSButton *hideInDock;
@property (weak) IBOutlet NSButton *showInMenuButton;
@property (weak) IBOutlet NSTextField *restartRequiredLabel;

@property (strong) LGToolManager *toolManager;

@end
