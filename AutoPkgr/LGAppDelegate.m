//
//  LGAppDelegate.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAppDelegate.h"
#import "LGConstants.h"
#import "LGConfigurationWindowController.h"

@implementation LGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self setupStatusItem];

    // Show the configuration window if we haven't
    // completed the initial setup
    //
    // TODO: This raises an exception. Fix it.
//    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//    if ([defaults objectForKey:kHasCompletedInitialSetup]) {
//        [self showConfigurationWindow:nil];
//    }
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setTitle:@""];
    [self.statusItem setImage:[NSImage imageNamed:@"autopkgr.png"]];
    [self.statusItem setAlternateImage:[NSImage imageNamed:@"autopkgr_alt.png"]];
    [self.statusItem setHighlightMode:YES];
    [self setupMenu];
}

- (void)setupMenu
{
    // Setup menu items for statusItem
    NSMenu *menu = [[NSMenu alloc] init];
//    [menu addItemWithTitle:@"Send Test Email..." action:@selector(sendTestEmailFromMenu) keyEquivalent:@""];
//    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Configure..." action:@selector(showConfigurationWindow:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    self.statusItem.menu = menu;
}

- (void)showConfigurationWindow:(id)sender
{
    if (!configurationWindowController) {
        configurationWindowController = [[LGConfigurationWindowController alloc] initWithWindowNibName:@"LGConfigurationWindowController"];
    }
    [configurationWindowController showWindow:self];
}

@end
