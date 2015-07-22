//
//  LGTableCellViews.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/31/15.
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

#pragma mark - Recipe Cell View
@interface LGRecipeStatusCellView : NSTableCellView

@property (assign) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) IBOutlet NSButton *enabledCheckBox;

@end

#pragma mark - Repo Cell View
@interface LGRepoStatusCellView : NSTableCellView

@property (assign) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) IBOutlet NSButton *enabledCheckBox;

@end

#pragma mark - Integration Cell View
@interface LGIntegrationStatusTableCellView : NSTableCellView

@property (assign) IBOutlet NSButton *installButton;
@property (assign) IBOutlet NSButton *configureButton;

@property (assign) IBOutlet NSProgressIndicator *progressIndicator;

@end
