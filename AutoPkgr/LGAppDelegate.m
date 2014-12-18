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
#import "LGHostInfo.h"
#import "LGAutoPkgTask.h"
#import "LGEmailer.h"
#import "LGAutoPkgSchedule.h"
#import "LGRecipes.h"
#import "LGConfigurationWindowController.h"
#import "LGAutoPkgrHelperConnection.h"
#import "LGUserNotifications.h"
#import <AHLaunchCtl/AHLaunchCtl.h>

@implementation LGAppDelegate {
@private
    LGConfigurationWindowController *_configurationWindowController;
    BOOL _configurationWindowInitiallyVisible;
    LGUserNotifications *notificationDelegate;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSLog(@"Welcome to AutoPkgr!");
    DLog(@"Verbose logging is active. To deactivate, option-click the AutoPkgr menu icon and uncheck Verbose Logs.");

    // Setup the status item
    [self setupStatusItem];
    
    // Check if we're authorized to install helper tool,
    // if not just quit
    NSError *error;
    if (![AHLaunchCtl installHelper:kLGAutoPkgrHelperToolName prompt:@"To schedule" error:&error]) {
        if (error) {
            NSLog(@"%@", error.localizedDescription);
            [NSApp presentError:[NSError errorWithDomain:kLGApplicationName code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"The associated helper tool could not be installed, we must now quit" }]];
            [[NSApplication sharedApplication] terminate:self];
        }
    }

    if(![LGRecipes migrateToIdentifiers:nil]){
        [NSApp presentError:[NSError errorWithDomain:kLGApplicationName code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"AutoPkgr will now quit.",
            NSLocalizedRecoverySuggestionErrorKey:@"You've chosen to not upgrade your recipe list. Either relaunch AutoPkgr to restart the migration process, or downgrade to an older 1.1.x AutoPkgr release." }]];
        [[NSApplication sharedApplication] terminate:self];
    }

    // Setup User Notification Delegate
    notificationDelegate = [[LGUserNotifications alloc] init];
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = notificationDelegate;

    [self showConfigurationWindow:self];
}

- (void)setupStatusItem
{
    // Setup the systemStatusBar
    DLog(@"Starting AutoPkgr menu bar icon...");
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [self.statusItem setMenu:self.statusMenu];

    NSImage *image = [NSImage imageNamed:@"autopkgr.png"];
    [image setTemplate:YES];
    [self.statusItem setImage:image];

    NSImage *altImage = [NSImage imageNamed:@"autopkgr_alt.png"];
    [altImage setTemplate:YES];
    [self.statusItem setAlternateImage:altImage];

    [self.statusItem setHighlightMode:YES];
    self.statusItem.menu = self.statusMenu;
    DLog(@"AutoPkgr menu bar icon started.");
}

- (void)checkNowFromMenu:(id)sender
{
    DLog(@"Received 'Check Now' menulet command.");

    [self startProgressWithMessage:@"Running selected AutoPkg recipes."];
    NSString *recipeList = [LGRecipes recipeList];
    BOOL updateRepos = [[LGDefaults standardUserDefaults] checkForRepoUpdatesAutomaticallyEnabled];

    LGAutoPkgTaskManager *manager = [[LGAutoPkgTaskManager alloc] init];
    manager.progressDelegate = self;
    [manager runRecipeList:recipeList
                updateRepo:updateRepos
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

- (IBAction)uninstallHelper:(id)sender
{
    LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
    LGDefaults *defaults = [[LGDefaults alloc]init];
    
    NSData *authData = [LGAutoPkgrAuthorizer authorizeHelper];
    
    [helper connectToHelper];
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [NSApp presentError:error];
    }]  uninstall:authData reply:^(NSError *error) {
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if(error){
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [NSApp presentError:error];
                }];
            } else {
                // if uninstalling turn off schedule in defaults so it's not automatically recreated
                defaults.checkForNewVersionsOfAppsAutomaticallyEnabled = NO;
                NSAlert *alert = [NSAlert alertWithMessageText:@"Removed AutoPkgr Associated files" defaultButton:@"Thanks for using AutoPkgr" alternateButton:nil otherButton:nil informativeTextWithFormat: @"including the helper tool, launchd schedule, and other launchd plist.  You can safely remove it from your Application Folder"];
                [alert runModal];
                [[NSApplication sharedApplication]terminate:self];
            }
        }];
    }];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (jobIsRunning(kLGAutoPkgrHelperToolName, kAHGlobalLaunchDaemon)) {
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];
        [[helper.connection remoteObjectProxy] quitHelper:^(BOOL success) {}];
    }
}

#pragma mark - Progress Protocol
- (void)startProgressWithMessage:(NSString *)message
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _configurationWindowInitiallyVisible = [_configurationWindowController.window isVisible];

        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController startProgressWithMessage:message];
        }
        NSMenuItem *item = [self.statusMenu itemAtIndex:0];
        [item setAction:nil];
        [item setTitle:message];
    }];
}

- (void)stopProgress:(NSError *)error
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController stopProgress:error];
        }

        NSMenuItem *item = [self.statusMenu itemAtIndex:0];
        [item setTitle:@"Check Now"];
        [item setAction:@selector(checkNowFromMenu:)];
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController updateProgress:message progress:progress];
        }

        if (message.length < 50) {
                [[self.statusMenu itemAtIndex:0] setTitle:message];
        }
        NSLog(@"%@", message);
    }];
}

@end
