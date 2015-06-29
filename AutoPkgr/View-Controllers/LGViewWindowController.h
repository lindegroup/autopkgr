//
//  LGConfigWindowController.h
//  AutoPkgr
//
//  Created by Eldon on 6/6/15.
//  Copyright (c) 2015 Eldon Ahrold.
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

@interface LGViewWindowController : NSWindowController
- (instancetype)init __unavailable;
- (instancetype)initWithViewController:(NSViewController *)viewController;

@property (strong, nonatomic, readonly) NSViewController *viewController;

@property (weak) IBOutlet NSBox *configBox;
@property (weak) IBOutlet NSButton *accessoryButton;
@property (weak) IBOutlet NSProgressIndicator *progressSpinner;

@property (weak) IBOutlet NSTextField *infoTextField;
@property (weak) IBOutlet NSButton *urlLinkButton;

@end
