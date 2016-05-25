//
//  LGAppDelegate.h
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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
#import "LGProgressDelegate.h"

@class LGConfigurationWindowController;

@interface LGAppDelegate : NSObject <NSApplicationDelegate, LGProgressDelegate>

//@property (assign) IBOutlet NSWindow *window;
@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusItem;

// Links to status menu items.
@property (weak, nonatomic) IBOutlet NSMenuItem *progressMenuItem;
@property (weak, nonatomic) IBOutlet NSMenuItem *runUpdatesNowMenuItem;
@property (weak, nonatomic) IBOutlet NSMenuItem *autoCheckForUpdatesMenuItem;

- (IBAction)checkNowFromMenu:(id)sender;
- (IBAction)showConfigurationWindow:(id)sender;

// Links to AutoPkgr website and support site.
- (IBAction)openHelpSite:(id)sender;
- (IBAction)openHomeSite:(id)sender;

@end
