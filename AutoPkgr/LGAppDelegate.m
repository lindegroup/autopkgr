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

@interface LGAppDelegate ()
@property (strong) LGConfigurationWindowController *configurationWindowController;
@property (strong) LGUserNotifications *notificationDelegate;
@property (strong) LGAutoPkgTaskManager *taskManager;
@end

@implementation LGAppDelegate {
@private
    BOOL _configurationWindowInitiallyVisible;
    BOOL _initialMessageFromBackgroundRunProcessed;
}

#pragma mark - NSApplication Delegate
- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Setup activation policy
    if ([[LGDefaults standardUserDefaults] boolForKey:@"MenuBarOnly"]) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    // If this set to run as a stand alone app with no menu item,
    // quit it after the last window is closed.
    if ([NSApp activationPolicy] != NSApplicationActivationPolicyAccessory) {
        return YES;
    }
    return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{

    NSLog(@"Welcome to AutoPkgr!");
    DLog(@"Verbose logging is active. To deactivate, option-click the AutoPkgr menu icon and uncheck Verbose Logs.");

    // Start observing distributed notifications for background runs
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(didReceiveStatusUpdate:)
                                                            name:kLGNotificationProgressMessageUpdate
                                                          object:nil];
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

    if (![LGRecipes migrateToIdentifiers:nil]) {
        [NSApp presentError:[NSError errorWithDomain:kLGApplicationName code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"AutoPkgr will now quit.",
                                                                                            NSLocalizedRecoverySuggestionErrorKey : @"You've chosen to not upgrade your recipe list. Either relaunch AutoPkgr to restart the migration process, or downgrade to an older 1.1.x AutoPkgr release." }]];
        [[NSApplication sharedApplication] terminate:self];
    }

    // Setup User Notification Delegate
    _notificationDelegate = [[LGUserNotifications alloc] init];
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = _notificationDelegate;

    NSInteger timer;
    [_autoCheckForUpdatesMenuItem setState:[LGAutoPkgSchedule updateAppsIsScheduled:&timer]];

    NSString *menuItemTitle = [NSString stringWithFormat:@"Run AutoPkg Every %ld Hours", timer];

    [_autoCheckForUpdatesMenuItem setTitle:menuItemTitle];
    // calling stopProgress: here is a easy to get the
    //menu reset to it's default configuration
    [self stopProgress:nil];

    [self showConfigurationWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    if (jobIsRunning(kLGAutoPkgrHelperToolName, kAHGlobalLaunchDaemon)) {
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];
        [[helper.connection remoteObjectProxy] quitHelper:^(BOOL success) {}];
    }

    // Stop Observing...
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kLGNotificationProgressMessageUpdate object:nil];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self showConfigurationWindow:self];
    return YES;
}

#pragma mark - Setup
- (void)setupStatusItem
{
    LGDefaults *defaults = [LGDefaults standardUserDefaults];
    if (![defaults boolForKey:@"MenuBarOnly"] && [defaults boolForKey:@"DockOnly"]) {
        return;
    }

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

#pragma mark - IBActions
- (void)checkNowFromMenu:(id)sender
{
    DLog(@"Received 'Check Now' menulet command.");

    [self startProgressWithMessage:@"Running selected AutoPkg recipes."];
    NSString *recipeList = [LGRecipes recipeList];
    BOOL updateRepos = [[LGDefaults standardUserDefaults] checkForRepoUpdatesAutomaticallyEnabled];

    _taskManager = [[LGAutoPkgTaskManager alloc] init];
    _taskManager.progressDelegate = self;
    [_taskManager runRecipeList:recipeList
                     updateRepo:updateRepos
                          reply:^(NSDictionary *report, NSError *error) {
                              NSAssert([NSThread isMainThread], @"reply not on main thread!!");

                              [self stopProgress:error];
                              if (report.count || error) {
                                  LGEmailer *emailer = [LGEmailer new];
                                  [emailer sendEmailForReport:report error:error];
                              }
                          }];
}

- (void)cancelRunFromMenu:(id)sender
{
    if (_taskManager) {
        [_taskManager cancel];
    }
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
    LGDefaults *defaults = [[LGDefaults alloc] init];

    NSData *authData = [LGAutoPkgrAuthorizer authorizeHelper];

    [helper connectToHelper];
    [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        [NSApp presentError:error];
    }] uninstall:authData
            reply:^(NSError *error) {
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

#pragma mark - Progress Protocol
- (void)didReceiveStatusUpdate:(NSNotification *)aNotification
{
    NSDictionary *info = aNotification.userInfo;
    NSString *message = info[kLGNotificationUserInfoMessage];

    if (!_initialMessageFromBackgroundRunProcessed) {
        _configurationWindowInitiallyVisible = [_configurationWindowController.window isVisible];
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController startProgressWithMessage:@"Performing AutoPkg background run."];
        }
        _initialMessageFromBackgroundRunProcessed = YES;
    }

    if ([info[kLGNotificationUserInfoSuccess] boolValue]) {
        [self stopProgress:nil];
    } else {
        double progress = [info[kLGNotificationUserInfoProgress] doubleValue];
        [self updateProgress:message progress:progress];
    }
}

- (void)startProgressWithMessage:(NSString *)message
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _configurationWindowInitiallyVisible = [_configurationWindowController.window isVisible];

        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController startProgressWithMessage:message];
        }

        [_runUpdatesNowMenuItem setTitle:@"Cancel AutoPkg Run"];
        [_runUpdatesNowMenuItem setAction:@selector(cancelRunFromMenu:)];
    }];
}

- (void)stopProgress:(NSError *)error
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController stopProgress:error];
        }

        // Switch the title and selector back for run controller
        [_runUpdatesNowMenuItem setTitle:@"Run AutoPkg Now"];
        [_runUpdatesNowMenuItem setAction:@selector(checkNowFromMenu:)];

        // Set the last run date of the menu item.
        NSString *lastRunDate = [[LGDefaults standardUserDefaults] LastAutoPkgRun];
        NSString *status = [NSString stringWithFormat:@"Last AutoPkg Run: %@",lastRunDate ?: @"Never by AutoPkgr"];

        [_progressMenuItem setTitle:status];
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController updateProgress:message progress:progress];
        }

        if (message.length < 50) {
            NSMenuItem *runStatus = [self.statusMenu itemAtIndex:0];
            runStatus.title = message;
        }
        NSLog(@"%@", message);
    }];
}

- (IBAction)changeCheckForNewVersionsOfAppsAutomatically:(id)sender
{
    LGDefaults *_defaults = [LGDefaults standardUserDefaults];
    if ([sender isEqualTo:_autoCheckForUpdatesMenuItem]) {
        _autoCheckForUpdatesMenuItem.state = !_autoCheckForUpdatesMenuItem.state;
    }

    BOOL currentlyScheduled = [LGAutoPkgSchedule updateAppsIsScheduled:nil];

    NSLog(@"%@ autopkg run schedule.", currentlyScheduled ? @"Enabling" : @"Disabling");

    BOOL start = currentlyScheduled;
    if (![sender isEqualTo:_configurationWindowController.autoPkgRunInterval]) {
        start = [sender state];
    }

    BOOL force = NO;

    NSInteger interval = _configurationWindowController.autoPkgRunInterval.integerValue;

    if ([sender isEqualTo:_configurationWindowController.autoPkgRunInterval]) {
        if (!start || _defaults.autoPkgRunInterval == _configurationWindowController.autoPkgRunInterval.integerValue) {
            return;
        }
        // We set force here so it will reload the schedule
        // if it is currently enabled
        force = YES;
    }

    [LGAutoPkgSchedule startAutoPkgSchedule:start interval:interval isForced:force reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSInteger timer;
            BOOL currentlyScheduled = [LGAutoPkgSchedule updateAppsIsScheduled:&timer];
            _autoCheckForUpdatesMenuItem.state = currentlyScheduled;
            _configurationWindowController.checkForNewVersionsOfAppsAutomaticallyButton.state = currentlyScheduled;

            if (error) {
                    // If error, reset the state to modified status
                    _configurationWindowController.autoPkgRunInterval.stringValue = [@(timer) stringValue];

                    // If the authorization was canceled by user, don't present error.
                    if (error.code != kLGErrorAuthChallenge) {
                        [self stopProgress:error];
                    }
            } else {
                // Otherwise update our defaults
                NSString *menuItemTitle = [NSString stringWithFormat:@"Run AutoPkg Every %ld Hours", interval];
                [_autoCheckForUpdatesMenuItem setTitle:menuItemTitle];
            }
        }];
    }];
}

@end
