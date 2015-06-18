//
//  LGAppDelegate.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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
#import "LGAutoPkgRecipe.h"
#import "LGConfigurationWindowController.h"
#import "LGAutoPkgrHelperConnection.h"
#import "LGUserNotifications.h"
#import "LGDisplayStatusDelegate.h"

#import <AHLaunchCtl/AHLaunchCtl.h>

@interface LGAppDelegate () <NSMenuDelegate, LGDisplayStatusDelegate>
@property (strong) LGConfigurationWindowController *configurationWindowController;
@property (strong) LGUserNotifications *notificationDelegate;
@property (strong) LGAutoPkgTaskManager *taskManager;
@end

@implementation LGAppDelegate {
@private
    BOOL _configurationWindowInitiallyVisible;
    BOOL _configurationWindowDeferred;
    BOOL _initialMessageFromBackgroundRunProcessed;
}

#pragma mark - NSApplication Delegate
#pragma mark-- Launching --
- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Setup activation policy. By default set as menubar only.
    [[LGDefaults standardUserDefaults] registerDefaults:@{ kLGApplicationDisplayStyle : @(kLGDisplayStyleShowMenu | kLGDisplayStyleShowDock),
                                                           NSStringFromSelector(@selector(reportedItemFlags)) : @(kLGReportItemsAll) }];

    if (([[LGDefaults standardUserDefaults] applicationDisplayStyle] & kLGDisplayStyleShowDock)) {
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    }
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

    if (![AHLaunchCtl installHelper:kLGAutoPkgrHelperToolName prompt:@"" error:&error]) {
        if (error) {
            NSLog(@"%@", error.localizedDescription);
            [NSApp presentError:[NSError errorWithDomain:kLGApplicationName code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"The associated helper tool could not be installed, we must quit now." }]];
            [[NSApplication sharedApplication] terminate:self];
        }
    }

    // Register to get background progress updates...
    LGAutoPkgrHelperConnection *backgroundMonitor = [LGAutoPkgrHelperConnection new];

    [backgroundMonitor connectToHelper];
    backgroundMonitor.connection.exportedObject = self;
    backgroundMonitor.connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];

    [[backgroundMonitor.connection remoteObjectProxy] registerMainApplication:^(BOOL resign) {
        DLog(@"No longer monitoring scheduled autopkg run");
    }];

    if (![LGAutoPkgRecipe migrateToIdentifiers:nil]) {
        NSString *message = NSLocalizedString(@"AutoPkgr will now quit.", nil);
        NSString *suggestion = NSLocalizedString(@"You've chosen not to upgrade your recipe list. Either relaunch AutoPkgr to restart the migration process, or downgrade to an older 1.1.x AutoPkgr release.", nil);

        [NSApp presentError:
         [NSError errorWithDomain:kLGApplicationName
                             code:-1
                         userInfo:@{
                                    NSLocalizedDescriptionKey : message,
                                    NSLocalizedRecoverySuggestionErrorKey : suggestion
                                    }]];

        [[NSApplication sharedApplication] terminate:self];
    }

    // Setup User Notification Delegate
    _notificationDelegate = [[LGUserNotifications alloc] init];
    [NSUserNotificationCenter defaultUserNotificationCenter].delegate = _notificationDelegate;

    // calling stopProgress: here is an easy way to get the
    // menu reset to its default configuration
    [self stopProgress:nil];

    [self showConfigurationWindow:self];
}

#pragma mark-- Termination --
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    // If this set to run as dock only with no menu item, quit it after the last window is closed.
    BOOL quitOnClose = YES;

    if ([[LGDefaults standardUserDefaults] applicationDisplayStyle] & kLGDisplayStyleShowMenu) {
        quitOnClose = NO;
    }

    return quitOnClose;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    if (jobIsRunning(kLGAutoPkgrHelperToolName, kAHGlobalLaunchDaemon)) {
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];

        DLog(@"Sending quit signal to helper tool...");
        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
        }] quitHelper:^(BOOL success) {
            [[NSApplication sharedApplication] replyToApplicationShouldTerminate:YES];
        }];

        return NSTerminateLater;
    }
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    // Stop observing...
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:kLGNotificationProgressMessageUpdate object:nil];
}

#pragma mark-- Resigning --
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self showConfigurationWindow:self];
    return YES;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    // Write out preferences to disk to ensure the background run picks up any changes.
    [[LGDefaults standardUserDefaults] synchronize];
}

#pragma mark - Setup
- (void)setupStatusItem
{
    LGApplicationDisplayStyle style = [[LGDefaults standardUserDefaults] applicationDisplayStyle];

    if (!self.statusItem && (style & kLGDisplayStyleShowMenu)) {
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

        self.statusMenu.delegate = self;
    }
}

- (void)showStatusMenu:(id)sender
{
    if ([sender boolValue]) {
        [self setupStatusItem];
    } else {
        self.statusItem = nil;
    }
}

#pragma mark - IBActions
- (IBAction)openHelpSite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kLGAutoPkgrHelpWebsite]];
}

- (IBAction)openHomeSite:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kLGAutoPkgrWebsite]];
}

- (void)checkNowFromMenu:(id)sender
{
    DLog(@"Received 'Check Now' menulet command.");

    [self startProgressWithMessage:@"Running selected AutoPkg recipes..."];
    NSString *recipeList = [LGAutoPkgRecipe defaultRecipeList];
    BOOL updateRepos = [[LGDefaults standardUserDefaults] checkForRepoUpdatesAutomaticallyEnabled];

    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }
    _taskManager.progressDelegate = self;

    [_taskManager runRecipeList:recipeList
                     updateRepo:updateRepos
                          reply:^(NSDictionary *report, NSError *error) {
                              NSAssert([NSThread isMainThread], @"Reply not on main thread!");

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
    // If the application was launched at login, defer loading the configuration window once.
    if ([[[NSProcessInfo processInfo] arguments] containsObject:kLGLaunchedAtLogin]) {
        if (!_configurationWindowDeferred) {
            _configurationWindowDeferred = YES;
            return;
        }
    }

    if (!_configurationWindowController) {
        _configurationWindowController = [[LGConfigurationWindowController alloc] initWithProgressDelegate:self];
        _configurationWindowController.scheduleView.scheduleMenuItem = _autoCheckForUpdatesMenuItem;
    }

    [NSApp activateIgnoringOtherApps:YES];
    [self->_configurationWindowController.window makeKeyAndOrderFront:nil];
    DLog(@"Activated AutoPkgr configuration window.");
}

- (IBAction)uninstallHelper:(id)sender
{
    NSError *error;

    if (jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon)) {
        [[AHLaunchCtl sharedController] remove:kLGAutoPkgrLaunchDaemonPlist fromDomain:kAHGlobalLaunchDaemon error:&error];
        if (error) {
            NSLog(@"%@", error.localizedDescription);
        } else {
            NSLog(@"Disabled schedule.");
        }
    }

    if (![AHLaunchCtl uninstallHelper:kLGAutoPkgrHelperToolName prompt:@"Remove AutoPkgr's components." error:&error]) {
        if (error.code != errAuthorizationCanceled) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [NSApp presentError:error];
            }];
        }
    } else {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Removed AutoPkgr associated files." defaultButton:@"Thanks for using AutoPkgr" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This includes the helper tool, launchd schedule, and other launchd plist. You can safely remove it from your Applications folder."];
        [alert runModal];
        [[NSApplication sharedApplication] terminate:self];
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

        [_runUpdatesNowMenuItem setTitle:@"Cancel AutoPkg Run"];
        [_runUpdatesNowMenuItem setAction:@selector(cancelRunFromMenu:)];

        NSMenuItem *runStatus = [self.statusMenu itemAtIndex:0];
        runStatus.title = [message truncateToLength:50];
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
        NSString *status;

        if (error) {
            self.statusItem.image = [NSImage imageNamed:@"autopkgr_error.png"];
            status = [NSString stringWithFormat:@"AutoPkg Run Error on: %@",lastRunDate ?: @"Never by AutoPkgr"];
        } else {
            self.statusItem.image = [NSImage imageNamed:@"autopkgr.png"];
            status = [NSString stringWithFormat:@"Last AutoPkg Run: %@",lastRunDate ?: @"Never by AutoPkgr"];
        }

        [_progressMenuItem setTitle:status];
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (_configurationWindowController && _configurationWindowInitiallyVisible) {
            [_configurationWindowController updateProgress:message progress:progress];
        }

        NSMenuItem *runStatus = [self.statusMenu itemAtIndex:0];
        runStatus.title = [message truncateToLength:50];
    }];
}

- (void)bringAutoPkgrToFront
{
    if (!([[LGDefaults standardUserDefaults] applicationDisplayStyle] & kLGDisplayStyleShowDock)) {
        [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps];
    }
}

#pragma mark - Menu Delegate
- (void)menuWillOpen:(NSMenu *)menu
{
    // The preferences set via the background run are not picked up
    // despite aggressive synchronization, so we need to pull the value from
    // the actual preference file until a better work around is found...

    if (!_taskManager || _taskManager.operationCount == 0) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[@"~/Library/Preferences/com.lindegroup.AutoPkgr.plist" stringByExpandingTildeInPath]];

        NSString *date = [LGDefaults formattedDate:dict[@"LastAutoPkgRun"]];
        if (date) {
            NSString *status = [NSString stringWithFormat:@"Last AutoPkg Run: %@", date ?: @"Never by AutoPkgr"];
            _progressMenuItem.title = status;
        }
    }
}

- (void)menuDidClose:(NSMenu *)menu
{
    self.statusItem.image = [NSImage imageNamed:@"autopkgr.png"];
}

@end
