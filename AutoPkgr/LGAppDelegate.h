//
//  LGAppDelegate.h
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LGConfigurationWindowController;

@interface LGAppDelegate : NSObject <NSApplicationDelegate>
{
    @private
    LGConfigurationWindowController *configurationWindowController;
}

//@property (assign) IBOutlet NSWindow *window;
@property (strong, nonatomic) IBOutlet NSMenu *statusMenu;
@property (strong, nonatomic) NSStatusItem *statusItem;

- (IBAction)checkNowFromMenu:(id)sender;
- (IBAction)showConfigurationWindow:(id)sender;

@end
