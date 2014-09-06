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

@implementation LGAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    LGDefaults *defaults = [LGDefaults new];

    // Setup the status item
    [self setupStatusItem];

    // Show the configuration window
    [self showConfigurationWindow:nil];
    defaults.HasCompletedInitialSetup = YES;

    // Start the AutoPkg run timer if the user enabled it
    [self startAutoPkgRunTimer];

    // Update AutoPkg recipe repos when the application launches
    // if the user has enabled automatic repo updates
    if (defaults.checkForRepoUpdatesAutomaticallyEnabled) {
        NSLog(@"Updating AutoPkg recipe repos.");
        [self updateAutoPkgRecipeReposInBackgroundAtAppLaunch];
    }
}

- (void)startAutoPkgRunTimer
{
    LGAutoPkgSchedule *schedule = [[LGAutoPkgSchedule alloc] init];
    [schedule startTimer];
}


- (void)updateAutoPkgRecipeReposInBackgroundAtAppLaunch
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner invokeAutoPkgRepoUpdateInBackgroundThread];
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];
    [self.statusItem setImage:[NSImage imageNamed:@"autopkgr.png"]];
    [self.statusItem setAlternateImage:[NSImage imageNamed:@"autopkgr_alt.png"]];
    [self.statusItem setHighlightMode:YES];
    self.statusItem.menu = self.statusMenu;
}

- (void)checkNowFromMenu:(id)sender
{
    NSString *recipeList = [LGApplications recipeList];
    [LGAutoPkgTask runRecipeList:recipeList
                        progress:^(NSString *message, double taskProgress) {
                            NSLog(@"%@",message);
                        }
                           reply:^(NSDictionary *report,NSError *error) {
                            LGEmailer *emailer = [LGEmailer new];
                            [emailer sendEmailForReport:report error:error];
                        }];
}


- (void)showConfigurationWindow:(id)sender
{
    if (!self->configurationWindowController) {
        self->configurationWindowController = [[LGConfigurationWindowController alloc] initWithWindowNibName:@"LGConfigurationWindowController"];
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self->configurationWindowController.window makeKeyAndOrderFront:nil];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    LGDefaults *defaults = [LGDefaults new];

    if (defaults.warnBeforeQuittingEnabled) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Quit"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setMessageText:[NSString stringWithFormat:@"Are you sure you want to quit %@?", kLGApplicationName]];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ will not be able to run AutoPkg in the background or send email notifications until you relaunch the application.", kLGApplicationName]];
        [alert setAlertStyle:NSWarningAlertStyle];

        if ([alert runModal] == NSAlertSecondButtonReturn) {
            NSLog(@"User cancelled quit.");
            return NSTerminateCancel;
        }
    }

    return NSTerminateNow;
}

@end
