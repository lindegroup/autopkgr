//
//  LGConfigurationWindowController.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
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

#import "LGConfigurationWindowController.h"
#import "LGAutoPkgr.h"
#import "LGDefaults.h"
#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "LGAutoPkgTask.h"
#import "LGInstaller.h"
#import "LGAutoPkgSchedule.h"
#import "LGProgressDelegate.h"
#import "LGDisplayStatusDelegate.h"
#import "LGTools.h"
#import "LGPasswords.h"

@interface LGConfigurationWindowController () {
    LGDefaults *_defaults;
    LGAutoPkgTaskManager *_taskManager;
}

@end

@implementation LGConfigurationWindowController

#pragma mark - init/dealloc/nib

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _defaults = [LGDefaults new];
    }
    return self;
}

#pragma mark - NSWindowDelegate
- (void)windowDidLoad
{
    [super windowDidLoad];

    [LGPasswords migrateKeychainIfNeeded:^(NSString *password) {
        if (password) {
            _smtpPassword.stringValue = password;
        }
    }];

    // Populate the preference values from the user defaults, if they exist
    DLog(@"Populating configuration window settings based on user defaults, if they exist.");

    // Set up Progress Delegates
    if ([[[NSApplication sharedApplication] delegate] conformsToProtocol:@protocol(LGProgressDelegate)]) {
        _progressDelegate = (id)[[NSApplication sharedApplication] delegate];
    }

    _popRepoTableViewHandler.progressDelegate = _progressDelegate;

    // -- Set up the IBOutlets -- //

    // Modal Windows
    _popRepoTableViewHandler.modalWindow = self.window;

    // Set launch at login button
    _launchAtLoginButton.state = [LGAutoPkgSchedule willLaunchAtLogin];

    // Set display mode button
    LGApplicationDisplayStyle displayStyle = _defaults.applicationDisplayStyle;

    _hideInDock.state = !(displayStyle & kLGDisplayStyleShowDock);
    _showInMenuButton.state = (displayStyle & kLGDisplayStyleShowMenu);

    // AutoPkg settings
    _localMunkiRepo.safeStringValue = _defaults.munkiRepo;
    _autoPkgCacheDir.safeStringValue = _defaults.autoPkgCacheDir;
    _autoPkgRecipeRepoDir.safeStringValue = _defaults.autoPkgRecipeRepoDir;
    _autoPkgRecipeOverridesDir.safeStringValue = _defaults.autoPkgRecipeOverridesDir;

    // AutoPkgr Settings
    _smtpServer.safeStringValue = _defaults.SMTPServer;
    _smtpFrom.safeStringValue = _defaults.SMTPFrom;

    BOOL state;
    // A number of IBOutlets are enabled/disabled based on this value so we use a method
    state = _defaults.SMTPAuthenticationEnabled;
    _smtpAuthenticationEnabledButton.state = state;
    [self changeSmtpAuthentication:@(state)];

    state = _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled;
    _sendEmailNotificationsWhenNewVersionsAreFoundButton.state = state;
    [self changeSendEmailNotificationsWhenNewVersionsAreFound:@(state)];

    _smtpTLSEnabledButton.state = _defaults.SMTPTLSEnabled;

    // Set up schedule settings
    NSInteger timer;
    _checkForNewVersionsOfAppsAutomaticallyButton.state = [LGAutoPkgSchedule updateAppsIsScheduled:&timer];
    [_autoPkgRunInterval setIntegerValue:timer];

    [_checkForNewVersionsOfAppsAutomaticallyButton setTarget:_progressDelegate];
    [_checkForNewVersionsOfAppsAutomaticallyButton setAction:@selector(changeCheckForNewVersionsOfAppsAutomatically:)];

    _checkForRepoUpdatesAutomaticallyButton.state = _defaults.checkForRepoUpdatesAutomaticallyEnabled;

    NSString *userName = _defaults.SMTPUsername;
    if (userName) {
        _smtpUsername.safeStringValue = userName;
        [self getKeychainPassword:_smtpPassword];
    }

    // removeEmptyStrings is an NSArray category extension
    [_smtpTo setObjectValue:[_defaults.SMTPTo removeEmptyStrings]];

    if (_defaults.SMTPPort) {
        [_smtpPort setIntegerValue:_defaults.SMTPPort];
    }

    // Check to see what's installed, and what needs updating

    LGToolStatus *toolStatus = [[LGToolStatus alloc] init];
    [toolStatus autoPkgStatus:^(LGTool *tool) {
        _installAutoPkgButton.enabled = tool.needsInstall;
        _installAutoPkgButton.title = tool.installButtonTitle;
        _autoPkgStatusIcon.image = tool.statusImage;
        _autoPkgStatusLabel.stringValue = tool.statusString;
    }];

    [toolStatus gitStatus:^(LGTool *tool) {
        _installGitButton.enabled = tool.needsInstall;
        _installGitButton.title = tool.installButtonTitle;
        _gitStatusLabel.stringValue = tool.statusString;
        _gitStatusIcon.image = tool.statusImage;
    }];
}

- (BOOL)windowShouldClose:(id)sender
{
    DLog(@"Close command received. Configuration window is saving and closing.");
    return YES;
}

#pragma mark - Display Mode
- (IBAction)changeDisplayMode:(NSButton *)sender
{
    NSApplication *app = [NSApplication sharedApplication];

    LGApplicationDisplayStyle newStyle = kLGDisplayStyleShowNone;

    if (!_hideInDock.state) {
        newStyle = kLGDisplayStyleShowDock;
    }

    if (_showInMenuButton.state) {
        newStyle = newStyle | kLGDisplayStyleShowMenu;
    }

    [[LGDefaults standardUserDefaults] setApplicationDisplayStyle:newStyle];

    if ([sender isEqualTo:_hideInDock]) {
        _restartRequiredLabel.hidden = !sender.state;
        if (!sender.state) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        }
    }

    if ([sender isEqualTo:_showInMenuButton]) {
        if ([app.delegate respondsToSelector:@selector(showStatusMenu:)]) {
            [app.delegate performSelector:@selector(showStatusMenu:) withObject:@(_showInMenuButton.state)];
        }
    }
}

#pragma mark - Launch At Login
- (IBAction)launchAtLogin:(NSButton *)sender
{
    if (![LGAutoPkgSchedule launchAtLogin:sender.state]) {
        sender.state = !sender.state;
    }
}

#pragma mark - Email
- (IBAction)sendTestEmail:(id)sender
{
    // Send a test email notification when the user
    // clicks "Send Test Email"
    DLog(@"'Send Test Email' button clicked.");

    // Handle UI
    [_sendTestEmailButton setEnabled:NO]; // disable button
    [_sendTestEmailSpinner setHidden:NO]; // show spinner
    [_sendTestEmailSpinner startAnimation:self]; // animate spinner

    // Create an instance of the LGEmailer class
    LGEmailer *emailer = [[LGEmailer alloc] init];

    // Listen for notifications on completion
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(testEmailReceived:)
                                                 name:kLGNotificationEmailSent
                                               object:emailer];

    // Send the test email notification by sending the
    // sendTestEmail message to our object
    [emailer sendTestEmail];
}

- (void)testSmtpServerPort:(id)sender
{
    if (![[_smtpServer stringValue] isEqualToString:@""] && [_smtpPort integerValue] > 0) {

        DLog(@"Testing SMTP server and port settings.");
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

        // Set up the UI
        [_testSmtpServerStatus setHidden:YES];
        [_testSmtpServerSpinner setHidden:NO];
        [_testSmtpServerSpinner startAnimation:self];

        LGTestPort *tester = [[LGTestPort alloc] init];

        [center addObserver:self
                   selector:@selector(testSmtpServerPortNotificationReceived:)
                       name:kLGNotificationTestSmtpServerPort
                     object:nil];

        [tester testHost:[NSHost hostWithName:[_smtpServer stringValue]]
                withPort:[_smtpPort integerValue]];
    } else {
        NSLog(@"Cannot test SMTP. Either host is blank or port is unreadable.");
    }
}

#pragma mark - Keychain Actions
- (void)getKeychainPassword:(NSTextField *)sender
{
    NSString *account = _smtpUsername.stringValue;
    if (account.length) {
        [LGPasswords getPasswordForAccount:account reply:^(NSString *password, NSError *error) {
            if (error) {
                NSLog(@"Error getting password for %@ [%ld]: %@", account, error.code, error.localizedDescription);
            } else {
                sender.safeStringValue = password;
            }
        }];
    }
}

- (IBAction)updateKeychainPassword:(id)sender
{
    NSString *account = _smtpUsername.safeStringValue;
    NSString *password = _smtpPassword.safeStringValue;

    if (account && password) {
        [LGPasswords savePassword:password forAccount:account reply:^(NSError *error) {
            if (error) {
                if (error.code == errSecAuthFailed) {
                    [LGPasswords resetKeychainPrompt:^(NSError *error) {
                        if (!error) {
                            [self updateKeychainPassword:nil];
                        } else {
                            NSLog(@"%@", error.localizedDescription);
                        }
                    }];
                } else {
                    NSLog(@"Error setting password [%ld]: %@", error.code, error.localizedDescription);
                }
            }
        }];
    }
}

#pragma mark - AutoPkgr actions
- (IBAction)installGit:(id)sender
{
    NSLog(@"Installing Git...");

    // Change the button label to "Installing..."
    // and disable the button to prevent multiple clicks
    [_installGitButton setEnabled:NO];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = _progressDelegate;
    [installer installGit:^(NSError *error) {
        [self stopProgress:error];
        LGToolStatus *toolStatus = [[LGToolStatus alloc] init];
        [toolStatus autoPkgStatus:^(LGTool *tool) {
            _installGitButton.enabled = tool.needsInstall;
            _installGitButton.title = tool.installButtonTitle;
            _gitStatusIcon.image = tool.statusImage;
            _gitStatusLabel.stringValue = tool.statusString;
        }];
    }];
}

- (IBAction)installAutoPkg:(id)sender
{
    NSLog(@"Installing AutoPkg...");

    // Disable the button to prevent multiple clicks
    [_installAutoPkgButton setEnabled:NO];
    [self startProgressWithMessage:@"Installing newest version of AutoPkg..."];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = _progressDelegate;
    [installer installAutoPkg:^(NSError *error) {
        // Update the autoPkgStatus icon and label if it installed successfully
        [self stopProgress:error];
        LGToolStatus *toolStatus = [[LGToolStatus alloc] init];
        [toolStatus autoPkgStatus:^(LGTool *tool) {
            _installAutoPkgButton.enabled = tool.needsInstall;
            _installAutoPkgButton.title = tool.installButtonTitle;
            _autoPkgStatusIcon.image = tool.statusImage;
            _autoPkgStatusLabel.stringValue = tool.statusString;
        }];
    }];
}

#pragma mark - Open Folder Actions
- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    DLog(@"Opening Munki repo folder...");

    NSString *munkiRepoFolder = _defaults.munkiRepo;
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:munkiRepoFolder isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:munkiRepoFolder];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", munkiRepoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, munkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeRepos folder...");

    NSString *repoFolder = [_defaults autoPkgRecipeRepoDir];
    BOOL isDir;

    repoFolder = repoFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:repoFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeReposFolderURL = [NSURL fileURLWithPath:repoFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeReposFolderURL];
    } else {
        NSLog(@"%@ does not exist.", repoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeRepos folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeRepos folder located in %@. Please verify that this folder exists.", kLGApplicationName, repoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgCacheFolder:(id)sender
{
    DLog(@"Opening AutoPkg Cache folder...");

    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    BOOL isDir;

    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgCacheFolderURL = [NSURL fileURLWithPath:cacheFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgCacheFolderURL];
    } else {
        NSLog(@"%@ does not exist.", cacheFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg Cache folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg Cache folder located in %@. Please verify that this folder exists.", kLGApplicationName, cacheFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeOverrides folder...");

    NSString *overridesFolder = _defaults.autoPkgRecipeOverridesDir;
    BOOL isDir;

    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeOverridesFolderURL = [NSURL fileURLWithPath:overridesFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeOverridesFolderURL];
    } else {
        NSLog(@"%@ does not exist.", overridesFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeOverrides folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeOverrides folder located in %@. Please verify that this folder exists.", kLGApplicationName, overridesFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
    }
}

#pragma mark - Choose AutoPkg Folder Actions
- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    DLog(@"Showing dialog for selecting Munki repo location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.munkiRepo ?: @"/Users/Shared"]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"Munki repo location selected.");
                    NSString *urlPath = [url path];
                    [_localMunkiRepo setStringValue:urlPath];
                    [_openLocalMunkiRepoFolderButton setEnabled:YES];
                    _defaults.munkiRepo = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeRepos location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeRepoDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeRepos location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeRepoDir setStringValue:urlPath];
                    [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeRepoDir = urlPath;

                    // Since we changed the repo directory reload the table accordingly
                    [_popRepoTableViewHandler reload];
                }
            }
        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg Cache location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgCacheDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg Cache location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgCacheDir setStringValue:urlPath];
                    [_openAutoPkgCacheFolderButton setEnabled:YES];
                    _defaults.autoPkgCacheDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeOverrides location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeOverridesDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeOverrides location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeOverridesDir setStringValue:urlPath];
                    [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeOverridesDir = urlPath;
                }
            }

        }
    }];
}

#pragma mark - AutoPkg actions
- (IBAction)addAutoPkgRepoURL:(id)sender
{
    NSString *repo = [_repoURLToAdd stringValue];
    [self startProgressWithMessage:[NSString stringWithFormat:@"Adding %@", repo]];

    [LGAutoPkgTask repoAdd:repo reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self stopProgress:error];
            [_popRepoTableViewHandler reload];
            [_recipeTableViewHandler reload];
        }];
    }];
    [_repoURLToAdd setStringValue:@""];
}

- (IBAction)updateReposNow:(id)sender
{
    [_cancelAutoPkgRunButton setHidden:NO];
    [_progressDetailsMessage setHidden:NO];
    [_progressDelegate startProgressWithMessage:@"Updating AutoPkg recipe repos."];

    [_updateRepoNowButton setEnabled:NO];
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }

    _taskManager.progressDelegate = _progressDelegate;

    [_taskManager repoUpdate:^(NSError *error) {
        NSAssert([NSThread isMainThread], @"Reply not on main thread!");
        [_progressDelegate stopProgress:error];
        [_updateRepoNowButton setEnabled:YES];
        [_recipeTableViewHandler reload];
    }];
}

- (IBAction)checkAppsNow:(id)sender
{
    NSString *recipeList = [LGRecipes recipeList];
    if (!_taskManager) {
        _taskManager = [[LGAutoPkgTaskManager alloc] init];
    }

    _taskManager.progressDelegate = _progressDelegate;

    [_cancelAutoPkgRunButton setHidden:NO];
    [_progressDetailsMessage setHidden:NO];
    [_progressDelegate startProgressWithMessage:@"Running selected AutoPkg recipes."];

    [_taskManager runRecipeList:recipeList
                     updateRepo:NO
                          reply:^(NSDictionary *report, NSError *error) {
                              NSAssert([NSThread isMainThread], @"Reply not on main thread!");

                                [_progressDelegate stopProgress:error];
                                if (report.count || error) {
                                    LGEmailer *emailer = [LGEmailer new];
                                    [emailer sendEmailForReport:report error:error];
                                }
                          }];
}

- (IBAction)cancelAutoPkgRun:(id)sender
{
    if (_taskManager) {
        [_taskManager cancel];
    }
}

#pragma mark - State Actions
- (IBAction)changeCheckForNewVersionsOfAppsAutomatically:(id)sender
{
    [_progressDelegate changeCheckForNewVersionsOfAppsAutomatically:sender];
}

- (IBAction)changeCheckForRepoUpdatesAutomatically:(NSButton *)sender
{
    _defaults.checkForRepoUpdatesAutomaticallyEnabled = sender.state;
    NSLog(@"%@ updating repos automatically before scheduled run.", _defaults.checkForRepoUpdatesAutomaticallyEnabled ? @"Enabling" : @"Disabling");
}

- (IBAction)changeSendEmailNotificationsWhenNewVersionsAreFound:(id)sender
{
    // Internally
    BOOL enabled = YES;
    if ([sender isKindOfClass:[NSButton class]]) {
        enabled = [sender state];
        _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled = enabled;
        NSLog(@"%@ email notifications.", enabled ? @"Enabling" : @"Disabling");
    } else if ([sender isKindOfClass:[NSNumber class]]) {
        enabled = [sender boolValue];
    }

    [_smtpTo setEnabled:enabled];
    [_smtpServer setEnabled:enabled];

    [_smtpPort setEnabled:enabled];
    [_sendTestEmailButton setEnabled:enabled];
    [_smtpFrom setEnabled:enabled];
    [_smtpAuthenticationEnabledButton setEnabled:enabled];

    BOOL authEnabled = _defaults.SMTPAuthenticationEnabled && enabled;

    [_smtpTLSEnabledButton setEnabled:authEnabled];
    [_smtpUsername setEnabled:authEnabled];
    [_smtpPassword setEnabled:authEnabled];
}

- (IBAction)changeSmtpAuthentication:(id)sender
{
    BOOL enabled = YES;
    if ([sender isKindOfClass:[NSButton class]]) {
        enabled = [sender state];
        _defaults.SMTPAuthenticationEnabled = enabled;
        NSLog(@"%@ SMTP authentication.", enabled ? @"Enabling" : @"Disabling");
    } else if ([sender isKindOfClass:[NSNumber class]]) {
        enabled = [sender boolValue];
    }

    [_smtpUsername setEnabled:enabled];
    [_smtpPassword setEnabled:enabled];
    [_smtpTLSEnabledButton setEnabled:enabled];
}

- (IBAction)changeTLSButtonState:(NSButton *)sender;
{
    if (sender.state) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [_defaults setBool:YES forKey:kLGSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [_defaults setBool:NO forKey:kLGSMTPTLSEnabled];
    }
}

#pragma mark - NSTextDelegate
- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id object = [notification object];

    if ([object isEqual:_smtpServer]) {
        _defaults.SMTPServer = [_smtpServer stringValue];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:_smtpPort]) {
        _defaults.SMTPPort = [_smtpPort integerValue];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:_smtpUsername]) {
        _defaults.SMTPUsername = [_smtpUsername stringValue];
        [self getKeychainPassword:_smtpPassword];
    } else if ([object isEqual:_smtpFrom]) {
        _defaults.SMTPFrom = [_smtpFrom stringValue];
    } else if ([object isEqual:_localMunkiRepo]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[_localMunkiRepo stringValue] isEqualToString:@""] ? nil : [_localMunkiRepo stringValue];
        _defaults.munkiRepo = value;
        [self enableOpenInFinderButtons];
    } else if ([object isEqual:_autoPkgRecipeOverridesDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[_autoPkgRecipeOverridesDir stringValue] isEqualToString:@""] ? nil : [_autoPkgRecipeOverridesDir stringValue];
        _defaults.autoPkgRecipeOverridesDir = value;
        [self enableOpenInFinderButtons];
    } else if ([object isEqual:_autoPkgRecipeRepoDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[_autoPkgRecipeRepoDir stringValue] isEqualToString:@""] ? nil : [_autoPkgRecipeRepoDir stringValue];
        _defaults.autoPkgRecipeRepoDir = value;
        [self enableOpenInFinderButtons];
    } else if ([object isEqual:_autoPkgCacheDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[_autoPkgCacheDir stringValue] isEqualToString:@""] ? nil : [_autoPkgCacheDir stringValue];
        _defaults.autoPkgCacheDir = value;
        [self enableOpenInFinderButtons];
    } else if ([object isEqual:_smtpTo]) {
        // We use objectValue here because objectValue returns an
        // array of strings if the field contains a series of strings
        _defaults.SMTPTo = [_smtpTo objectValue];
    } else if ([object isEqual:_autoPkgRunInterval]) {
        [_progressDelegate changeCheckForNewVersionsOfAppsAutomatically:_autoPkgRunInterval];
    } else if ([object isEqual:_smtpPassword]) {
        // This is now handled with an IBAction
    }
}

#pragma mark - NSTokenFieldDelegate
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    if ([tokenField isEqual:_smtpTo]) {
        _defaults.SMTPTo = [tokenField objectValue];
    }
    return tokens;
}

#pragma mark - Tab View Delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([tabViewItem.identifier isEqualTo:@"localFolders"]) {
        [self enableOpenInFinderButtons];
    }
}

- (void)enableOpenInFinderButtons
{
    // Enable "Open in Finder" buttons if directories exist
    BOOL isDir;

    // AutoPkg Recipe Repos
    NSString *recipeReposFolder = [_defaults autoPkgRecipeRepoDir];
    recipeReposFolder = recipeReposFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:recipeReposFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeReposFolderButton setEnabled:NO];
    }

    // AutoPkg Cache
    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgCacheFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgCacheFolderButton setEnabled:NO];
    }

    // AutoPkg Overrides
    NSString *overridesFolder = [_defaults autoPkgRecipeOverridesDir];
    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:NO];
    }

    // Munki Repo
    if ([[NSFileManager defaultManager] fileExistsAtPath:_defaults.munkiRepo isDirectory:&isDir] && isDir) {
        [_openLocalMunkiRepoFolderButton setEnabled:YES];
    } else {
        [_openLocalMunkiRepoFolderButton setEnabled:NO];
    }
}

#pragma mark - LGProgressDelegate
- (void)startProgressWithMessage:(NSString *)message
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.progressMessage setStringValue:message];
        [self.progressDetailsMessage setStringValue:@""];

        [self.progressIndicator setHidden:NO];
        [self.progressIndicator setIndeterminate:YES];
        [self.progressIndicator displayIfNeeded];
        [self.progressIndicator startAnimation:nil];
        [NSApp beginSheet:self.progressPanel modalForWindow:self.window modalDelegate:self didEndSelector:nil contextInfo:NULL];
    }];
}

- (void)stopProgress:(NSError *)error
{
    // Stop the progress panel, and if and error was sent in
    // do a sheet modal
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        // Give the progress panel a second to got to 100%
        [self.progressIndicator setDoubleValue:100.0];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];

        [NSApp endSheet:self.progressPanel returnCode:0];
        [self.progressIndicator setIndeterminate:YES];
        [self.progressPanel orderOut:self];
        [self.cancelAutoPkgRunButton setHidden:YES];

        [self.progressDetailsMessage setStringValue:@""];
        [self.progressMessage setStringValue:@"Starting..."];
        [self.progressIndicator setDoubleValue:0.0];

        if (error) {
            SEL selector = nil;
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert addButtonWithTitle:@"OK"];
            // If AutoPkg exits -1 it may be misconfigured
            if (error.code == kLGErrorAutoPkgConfig) {
                [alert addButtonWithTitle:@"Try to repair settings"];
                selector = @selector(didEndWithPreferenceRepairRequest:returnCode:);
            }

            [alert beginSheetModalForWindow:self.window
                              modalDelegate:self
                             didEndSelector:selector
                                contextInfo:nil];
        }
    }];
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressIndicator setIndeterminate:NO];
            [self.progressDetailsMessage setStringValue:[message truncateToLength:100]];
            [self.progressIndicator setDoubleValue:progress > 5.0 ? progress:5.0 ];
    }];
}

#pragma mark - Notifications
- (void)testEmailReceived:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationEmailSent
                                                  object:[notification object]];

    [_sendTestEmailButton setEnabled:YES]; // enable button

    // Handle Spinner
    [_sendTestEmailSpinner stopAnimation:self]; // stop animation
    [_sendTestEmailSpinner setHidden:YES]; // hide spinner

    // pull the error out of the userInfo dictionary
    id error = [notification.userInfo objectForKey:kLGNotificationUserInfoError];

    if ([error isKindOfClass:[NSError class]]) {
        [self stopProgress:error];
    }
}

- (void)testSmtpServerPortNotificationReceived:(NSNotification *)notification
{
    // Set up the spinner and show the status image
    [_testSmtpServerSpinner setHidden:YES];
    [_testSmtpServerSpinner stopAnimation:self];
    [_testSmtpServerStatus setHidden:NO];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationTestSmtpServerPort
                                                  object:nil];

    NSString *status = notification.userInfo[kLGNotificationUserInfoSuccess];
    if ([status isEqualTo:@NO]) {
        [_testSmtpServerStatus setImage:[NSImage LGStatusUnavailable]];
    } else if ([status isEqualTo:@YES]) {
        [_testSmtpServerStatus setImage:[NSImage LGStatusAvailable]];
    } else {
        NSLog(@"Unexpected result for received from port test.");
        [_testSmtpServerStatus setImage:[NSImage LGStatusPartiallyAvailable]];
    }
}

#pragma mark - NSAlert didEndWith selectors
- (void)didEndWithPreferenceRepairRequest:(NSAlert *)alert returnCode:(NSInteger)returnCode
{
    if (returnCode == NSAlertSecondButtonReturn) {
        NSError *error;
        NSInteger neededFixing;
        BOOL rc = [LGDefaults fixRelativePathsInAutoPkgDefaults:&error neededFixing:&neededFixing];
        if (neededFixing > 0) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = [NSString stringWithFormat:@"%ld problems were found in the AutoPkg preference file", neededFixing];
            alert.informativeText = rc ? @"AutoPkgr was able to repair the AutoPkg preference file. No further action is required." : @"AutoPkgr could not repair the AutoPkg preference file. If the problem persists open an issue on the AutoPkgr GitHub page.";
            [alert beginSheetModalForWindow:self.window
                              modalDelegate:self
                             didEndSelector:nil
                                contextInfo:nil];
        } else {
            DLog(@"No problems were detected in the AutoPkg preference file.");
        }
    }
}

#pragma mark - Utility
- (NSOpenPanel *)setupChoosePanel
{
    NSOpenPanel *choosePanel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    [choosePanel setCanChooseFiles:NO];

    // Enable the selection of directories in the dialog
    [choosePanel setCanChooseDirectories:YES];

    // Enable the creation of directories in the dialog
    [choosePanel setCanCreateDirectories:YES];

    // Set the prompt to "Choose" instead of "Open"
    [choosePanel setPrompt:@"Choose"];

    // Disable multiple selection
    [choosePanel setAllowsMultipleSelection:NO];

    return choosePanel;
}

@end
