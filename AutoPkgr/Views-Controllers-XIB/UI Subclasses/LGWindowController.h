//
//  LGWindowController.h
//  AutoPkgr
//
//  Created by Eldon on 12/7/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LGWindowController;

typedef void (^windowCloseHandle)(LGWindowController *windowController);

@interface LGWindowController : NSWindowController

- (void)open:(windowCloseHandle)complete;
- (void)openSheetOnWindow:(NSWindow *)window complete:(windowCloseHandle)complete;

- (IBAction)close:(id)sender;
- (IBAction)closeSheet:(id)sender;
@end
