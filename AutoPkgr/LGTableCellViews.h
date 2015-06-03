//
//  LGRecipeStatusCellView.h
//  AutoPkgr
//
//  Created by Eldon on 5/31/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
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

#pragma mark - Tool Cell View
@interface LGToolStatusTableCellView : NSTableCellView

@property (assign) IBOutlet NSButton *installButton;
@property (assign) IBOutlet NSProgressIndicator *progressIndicator;
@property (assign) IBOutlet NSButton *configureButton;
@property (assign) IBOutlet NSButton *enabledCheckBox;

@end
