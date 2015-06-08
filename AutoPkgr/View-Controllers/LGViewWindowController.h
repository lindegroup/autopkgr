//
//  LGConfigWindowController.h
//  AutoPkgr
//
//  Created by Eldon on 6/6/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class LGBaseIntegrationViewController;

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
