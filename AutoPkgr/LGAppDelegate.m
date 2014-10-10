//
//  LGAppDelegate.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
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

#import "LGAppDelegate.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgTask.h"
#import "LGEmailer.h"
#import "LGAutoPkgSchedule.h"
#import "LGConfigurationWindowController.h"

@implementation LGAppDelegate {
@private
    LGConfigurationWindowController *_configurationWindowController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"Welcome to AutoPkgr!");
    DLog(@"Verbose logging is active. To deactivate, option-click the AutoPkgr menu icon and uncheck Verbose Logs.");

    LGDefaults *defaults = [LGDefaults new];

    // Set self as the delegate for the time so the menu item is updated
    // during timed runs.
    [[LGAutoPkgSchedule sharedTimer] setProgressDelegate:self];

    // Setup the status item
    [self setupStatusItem];

    // Show the configuration window
    [self showConfigurationWindow:nil];
    defaults.HasCompletedInitialSetup = YES;

    // Start the AutoPkg run timer if the user enabled it
    [self startAutoPkgRunTimer];
}

- (void)startAutoPkgRunTimer
{
    [[LGAutoPkgSchedule sharedTimer] configure];
}

- (void)updateAutoPkgRecipeReposInBackgroundAtAppLaunch
{
    NSLog(@"Updating AutoPkg repos...");
    [LGAutoPkgTask repoUpdate:^(NSError *error) {
       NSLog(@"%@", error ? error.localizedDescription:@"AutoPkg repos updated.");
    }];
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    DLog(@"Starting AutoPkgr menu bar icon...");
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setImage:[NSImage imageNamed:@"autopkgr.png"]];
    [self.statusItem setAlternateImage:[NSImage imageNamed:@"autopkgr_alt.png"]];
    [self.statusItem setHighlightMode:YES];
    self.statusItem.menu = self.statusMenu;
    DLog(@"AutoPkgr menu bar icon started.");
}

- (void)checkNowFromMenu:(id)sender
{
    DLog(@"Received 'Check Now' menulet command.");
    [self startProgressWithMessage:@"Starting..."];
    NSString *recipeList = [LGRecipes recipeList];
    [LGAutoPkgTask runRecipeList:recipeList
        progress:^(NSString *message, double taskProgress) {
                            [self updateProgress:message progress:taskProgress];
        }
        reply:^(NSDictionary *report, NSError *error) {
                               [self stopProgress:error];
                               LGEmailer *emailer = [LGEmailer new];
                               [emailer sendEmailForReport:report error:error];
        }];
}

- (void)showConfigurationWindow:(id)sender
{
    if (!self->_configurationWindowController) {
        self->_configurationWindowController = [[LGConfigurationWindowController alloc] initWithWindowNibName:@"LGConfigurationWindowController"];
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self->_configurationWindowController.window makeKeyAndOrderFront:nil];
    DLog(@"Activated AutoPkgr configuration window.");
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    DLog(@"Quit command received.");
    LGDefaults *defaults = [LGDefaults new];

    if (defaults.warnBeforeQuittingEnabled) {
        DLog(@"Warn before quitting is enabled. Displaying dialog box: 'Are you sure you want to quit AutoPkgr?'");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Quit"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to quit %@?", kLGApplicationName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ will not be able to run AutoPkg in the background or send email notifications until you relaunch the application.", kLGApplicationName]];
        [alert setAlertStyle:NSWarningAlertStyle];

        if ([alert runModal] == NSAlertSecondButtonReturn) {
            DLog(@"Quit canceled.");
            return NSTerminateCancel;
        }
    }

    NSLog(@"Now quitting AutoPkgr. Come back soon.");
    return NSTerminateNow;
}

#pragma mark - Progress Protocol
- (void)startProgressWithMessage:(NSString *)message
{
    if (_configurationWindowController && [_configurationWindowController.window isVisible]) {
        [_configurationWindowController startProgressWithMessage:message];
    }
    __block NSMenuItem *item = [self.statusMenu itemAtIndex:0];
    [item setAction:nil];
    [item setTitle:message];
}

- (void)stopProgress:(NSError *)error
{
    if (_configurationWindowController && [_configurationWindowController.window isVisible]) {
        [_configurationWindowController stopProgress:error];
    }
    __block NSMenuItem *item = [self.statusMenu itemAtIndex:0];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [item setTitle:@"Check Now"];
        [item setAction:@selector(checkNowFromMenu:)];
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    if (_configurationWindowController && [_configurationWindowController.window isVisible]) {
        [_configurationWindowController updateProgress:message progress:progress];
    }
    __block NSMenuItem *item = [self.statusMenu itemAtIndex:0];
    if (message.length < 50) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [item setTitle:message];
        }];
    }
    NSLog(@"%@", message);
}

@end
