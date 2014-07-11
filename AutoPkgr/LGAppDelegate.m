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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kHasCompletedInitialSetup]) {

        BOOL hasCompletedInitialSetup = [[defaults objectForKey:kHasCompletedInitialSetup] boolValue];

        if (!hasCompletedInitialSetup) {
            [self showConfigurationWindow:nil];
        }
    } else {
        [self showConfigurationWindow:nil];
    }
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
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

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL warnBeforeQuitting = [[defaults objectForKey:kWarnBeforeQuittingEnabled] boolValue];

    if (warnBeforeQuitting) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Quit"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to quit %@?", kApplicationName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ will not be able to run AutoPkg recipes or send email notifications until you relaunch the application.", kApplicationName]];
        [alert setAlertStyle:NSWarningAlertStyle];

        if ([alert runModal] == NSAlertSecondButtonReturn) {
            NSLog(@"User cancelled quit.");
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
