//
//  LGJSSAddon.h
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import <Foundation/Foundation.h>
#import "LGDefaults.h"
#import "LGProgressDelegate.h"
#import "LGTableView.h"

@interface LGJSSAddon : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet LGTableView *jssDistributionPointTableView;
@property (weak) IBOutlet NSTextField *jssURLTF;
@property (weak) IBOutlet NSTextField *jssAPIUsernameTF;
@property (weak) IBOutlet NSTextField *jssAPIPasswordTF;
@property (weak) IBOutlet NSButton *jssReloadServerBT;
@property (weak) IBOutlet NSProgressIndicator *jssStatusSpinner;
@property (weak) IBOutlet NSImageView *jssStatusLight;

@property (weak) IBOutlet NSButton *jssInstallButton;
@property (weak) IBOutlet NSImageView *jssInstallStatusLight;
@property (weak) IBOutlet NSTextField *jssInstallStatusTF;

@property (weak) IBOutlet NSWindow *modalWindow;

// Progress delegate (object used to send updates to status menu item)
@property (weak) id<LGProgressDelegate> progressDelegate;

- (IBAction)installJSSAddon:(id)sender;
- (IBAction) addDistributionPoint:(id)sender;

- (NSMenu *)contextualMenuForDistributionPoint:(NSDictionary *)distPoint;
@end
