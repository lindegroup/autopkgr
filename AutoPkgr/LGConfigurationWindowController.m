//
//  LGConfigurationWindowController.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
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

#import "LGConfigurationWindowController.h"
#import "LGAutoPkgr.h"
#import "LGDefaults.h"
#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "LGAutoPkgTask.h"
#import "LGInstaller.h"
#import "LGAutoPkgSchedule.h"
#import "LGProgressDelegate.h"
#import "LGGitHubJSONLoader.h"
#import "LGVersionComparator.h"
#import "SSKeychain.h"

@interface LGConfigurationWindowController () <LGProgressDelegate> {
    LGDefaults *_defaults;
    LGAutoPkgTask *_task;
}

@end

@implementation LGConfigurationWindowController

static void *XXCheckForNewAppsAutomaticallyEnabledContext = &XXCheckForNewAppsAutomaticallyEnabledContext;
static void *XXCheckForRepoUpdatesAutomaticallyEnabledContext = &XXCheckForRepoUpdatesAutomaticallyEnabledContext;
static void *XXEmailNotificationsEnabledContext = &XXEmailNotificationsEnabledContext;
static void *XXAuthenticationEnabledContext = &XXAuthenticationEnabledContext;


#pragma mark - init/dealloc/nib
- (void)dealloc
{
    [_smtpAuthenticationEnabledButton removeObserver:self forKeyPath:@"cell.state" context:XXAuthenticationEnabledContext];
    [_sendEmailNotificationsWhenNewVersionsAreFoundButton removeObserver:self forKeyPath:@"cell.state" context:XXEmailNotificationsEnabledContext];
    [_checkForNewVersionsOfAppsAutomaticallyButton removeObserver:self forKeyPath:@"cell.state" context:XXCheckForNewAppsAutomaticallyEnabledContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        _defaults = [LGDefaults new];
        _menuProgressDelegate = [NSApp delegate];
        
        NSNotificationCenter *ndc = [NSNotificationCenter defaultCenter];
        [ndc addObserver:self selector:@selector(startProgressNotificationReceived:) name:kLGNotificationProgressStart object:nil];
        [ndc addObserver:self selector:@selector(stopProgressNotificationReceived:) name:kLGNotificationProgressStop object:nil];
        [ndc addObserver:self selector:@selector(updateProgressNotificationReceived:) name:kLGNotificationProgressMessageUpdate object:nil];
    }
    return self;
}

- (void)awakeFromNib
{
    [_smtpAuthenticationEnabledButton addObserver:self
                                      forKeyPath:@"cell.state"
                                         options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                         context:XXAuthenticationEnabledContext];

    [_sendEmailNotificationsWhenNewVersionsAreFoundButton addObserver:self
                                                          forKeyPath:@"cell.state"
                                                             options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                                             context:XXEmailNotificationsEnabledContext];

    [_checkForNewVersionsOfAppsAutomaticallyButton addObserver:self
                                                   forKeyPath:@"cell.state"
                                                      options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                                      context:XXCheckForNewAppsAutomaticallyEnabledContext];

    // Set up buttons to save their defaults
    [_smtpTLSEnabledButton setTarget:self];
    [_smtpTLSEnabledButton setAction:@selector(changeTLSButtonState)];
    [_warnBeforeQuittingButton setTarget:self];
    [_warnBeforeQuittingButton setAction:@selector(changeWarnBeforeQuittingButtonState)];
    [_smtpAuthenticationEnabledButton setTarget:self];
    [_smtpAuthenticationEnabledButton setAction:@selector(changeSmtpAuthenticationButtonState)];
    [_sendEmailNotificationsWhenNewVersionsAreFoundButton setTarget:self];
    [_sendEmailNotificationsWhenNewVersionsAreFoundButton setAction:@selector(changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState)];
    [_checkForNewVersionsOfAppsAutomaticallyButton setTarget:self];
    [_checkForNewVersionsOfAppsAutomaticallyButton setAction:@selector(changeCheckForNewVersionsOfAppsAutomaticallyButtonState)];
    [_checkForRepoUpdatesAutomaticallyButton setTarget:self];
    [_checkForRepoUpdatesAutomaticallyButton setAction:@selector(changeCheckForRepoUpdatesAutomaticallyButtonState)];
}


#pragma mark - Observers
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == XXAuthenticationEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [_smtpUsername setEnabled:YES];
                [_smtpPassword setEnabled:YES];
                [_smtpTLSEnabledButton setEnabled:YES];
            } else {
                [_smtpUsername setEnabled:NO];
                [_smtpPassword setEnabled:NO];
                [_smtpTLSEnabledButton setEnabled:NO];
            }
        }
    } else if (context == XXEmailNotificationsEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [_smtpTo setEnabled:YES];
                [_smtpServer setEnabled:YES];
                [_smtpUsername setEnabled:YES];
                [_smtpPassword setEnabled:YES];
                [_smtpPort setEnabled:YES];
                [_smtpAuthenticationEnabledButton setEnabled:YES];
                [_smtpTLSEnabledButton setEnabled:YES];
                [_sendTestEmailButton setEnabled:YES];
                [_smtpFrom setEnabled:YES];
            } else {
                [_smtpTo setEnabled:NO];
                [_smtpServer setEnabled:NO];
                [_smtpUsername setEnabled:NO];
                [_smtpPassword setEnabled:NO];
                [_smtpPort setEnabled:NO];
                [_smtpAuthenticationEnabledButton setEnabled:NO];
                [_smtpTLSEnabledButton setEnabled:NO];
                [_sendTestEmailButton setEnabled:NO];
                [_smtpFrom setEnabled:NO];
            }
        }
    } else if (context == XXCheckForNewAppsAutomaticallyEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [_autoPkgRunInterval setEnabled:YES];
            } else {
                [_autoPkgRunInterval setEnabled:NO];
            }
        }
    }
}


#pragma mark - NSWindowDelegate
- (void)windowDidLoad
{
    [super windowDidLoad];

    // Populate the preference values from the user defaults, if they exist
    DLog(@"Populating configuration window settings based on user defaults, if they exist.");

    if ([_defaults autoPkgRunInterval]) {
        [_autoPkgRunInterval setIntegerValue:[_defaults autoPkgRunInterval]];
    }
    if ([_defaults munkiRepo]) {
        [_localMunkiRepo setStringValue:[_defaults munkiRepo]];
    }
    if ([_defaults autoPkgCacheDir]) {
        [_autoPkgCacheDir setStringValue:[_defaults autoPkgCacheDir]];
    }
    if ([_defaults autoPkgRecipeRepoDir]) {
        [_autoPkgRecipeRepoDir setStringValue:[_defaults autoPkgRecipeRepoDir]];
    }
    if ([_defaults autoPkgRecipeOverridesDir]) {
        [_autoPkgRecipeOverridesDir setStringValue:[_defaults autoPkgRecipeOverridesDir]];
    }
    if ([_defaults SMTPServer]) {
        [_smtpServer setStringValue:[_defaults SMTPServer]];
    }
    if ([_defaults SMTPFrom]) {
        [_smtpFrom setStringValue:[_defaults SMTPFrom]];
    }
    if ([_defaults SMTPPort]) {
        [_smtpPort setIntegerValue:[_defaults SMTPPort]];
    }
    if ([_defaults SMTPUsername]) {
        [_smtpUsername setStringValue:[_defaults SMTPUsername]];
    }
    if ([_defaults SMTPTo]) {
        NSArray *array = [_defaults SMTPTo];
        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in array) {
            if (![toAddress isEqual:@""]) {
                [to addObject:toAddress];
            }
        }
        [_smtpTo setObjectValue:to];
    }

    [_smtpTLSEnabledButton setState:[_defaults SMTPTLSEnabled]];

    [_smtpAuthenticationEnabledButton setState:[_defaults SMTPAuthenticationEnabled]];

    [_sendEmailNotificationsWhenNewVersionsAreFoundButton setState:[_defaults sendEmailNotificationsWhenNewVersionsAreFoundEnabled]];
    [_checkForNewVersionsOfAppsAutomaticallyButton setState:[_defaults checkForNewVersionsOfAppsAutomaticallyEnabled]];

    [_checkForRepoUpdatesAutomaticallyButton setState:[_defaults checkForRepoUpdatesAutomaticallyEnabled]];

    [_warnBeforeQuittingButton setState:[_defaults warnBeforeQuittingEnabled]];

    // Read the SMTP password from the keychain and populate in
    // NSSecureTextField if it exists
    NSError *error = nil;
    NSString *_smtpUsernameString = [_defaults SMTPUsername];

    if (_smtpUsernameString) {
        NSString *password = [SSKeychain passwordForService:kLGApplicationName
                                                    account:_smtpUsernameString
                                                      error:&error];

        if ([error code] == errSecItemNotFound) {
            NSLog(@"Keychain entry not found for account %@.", _smtpUsernameString);
        } else if ([error code] == errSecNotAvailable) {
            NSLog(@"Found the keychain entry for %@ but no password value was returned.", _smtpUsernameString);
        } else if (error != nil) {
            NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", _smtpUsernameString, [error localizedDescription]);
        } else {
            // Only populate the SMTP Password field if the username exists
            if (_smtpUsernameString && password && ![_smtpUsernameString isEqual:@""]) {
                NSLog(@"Successfully retrieved keychain entry for account %@.", _smtpUsernameString);
                [_smtpPassword setStringValue:password];
            }
        }
    }

    BOOL autoPkgInstalled = [LGHostInfo autoPkgInstalled];
    BOOL gitInstalled = [LGHostInfo gitInstalled];

    if (gitInstalled) {
        DLog(@"Git is installed. Disabling 'Install Git' button and setting green indicator.");
        [_installGitButton setEnabled:NO];
        [_gitStatusLabel setStringValue:kLGGitInstalledLabel];
        [_gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
    } else {
        DLog(@"Git is not installed. Enabling 'Install Git' button and setting red indicator.");
        [_installGitButton setEnabled:YES];
        [_gitStatusLabel setStringValue:kLGGitNotInstalledLabel];
        [_gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
    }

    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        // Since checking for an update can take some time, run it in the background
        if (autoPkgInstalled) {
            BOOL updateAvailable = [LGHostInfo autoPkgUpdateAvailable];
            if (updateAvailable) {
                DLog(@"AutoPkg is installed, but an update is available. Enabling 'Update AutoPkg' button and setting yellow indicator.");
                [_installAutoPkgButton setEnabled:YES];
                [_installAutoPkgButton setTitle:@"Update AutoPkg"];
                [_autoPkgStatusLabel setStringValue:kLGAutoPkgUpdateAvailableLabel];
                [_autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusPartiallyAvailable]];
            } else {
                DLog(@"AutoPkg is installed and up to date. Disabling 'Update AutoPkg' button and setting green indicator.");
                [_installAutoPkgButton setEnabled:NO];
                [_autoPkgStatusLabel setStringValue:kLGAutoPkgInstalledLabel];
                [_autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
            }
        } else {
            DLog(@"AutoPkg is not installed. Enabling 'Install AutoPkg' button and setting red indicator.");
            [_installAutoPkgButton setEnabled:YES];
            [_autoPkgStatusLabel setStringValue:kLGAutoPkgNotInstalledLabel];
            [_autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
        }
    }];

    // Update AutoPkg recipe repos when the application launches
    // if the user has enabled automatic repo updates
    if (_defaults.checkForRepoUpdatesAutomaticallyEnabled && gitInstalled && autoPkgInstalled) {
        [_updateRepoNowButton setEnabled:NO];
        [_checkAppsNowButton setEnabled:NO];
        [_updateRepoNowButton setTitle:@"Repos Updating..."];
        NSLog(@"Updating AutoPkg recipe repos...");
        [LGAutoPkgTask repoUpdate:^(NSError *error) {
            [_updateRepoNowButton setEnabled:YES];
            [_updateRepoNowButton setTitle:@"Update Repos Now"];
            [_checkAppsNowButton setEnabled:YES];
            NSLog(@"AutoPkg recipe repos updated.");
        }];
    }
    
    _popRepoTableViewHandler.progressDelegate = self;

    // Synchronize with the defaults database
    [_defaults synchronize];
}

- (BOOL)windowShouldClose:(id)sender
{
    DLog(@"Close command received. Configuration window is saving and closing.");
    [self save];
    return YES;
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
    // First saves the defaults
    [self save];

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

# pragma mark - AutoPkgr actions
- (void)save
{
    _defaults.SMTPServer = [_smtpServer stringValue];
    _defaults.SMTPPort = [_smtpPort integerValue];
    _defaults.SMTPUsername = [_smtpUsername stringValue];
    _defaults.SMTPFrom = [_smtpFrom stringValue];
    _defaults.HasCompletedInitialSetup = YES;

    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    _defaults.SMTPTo = [_smtpTo objectValue];

    // If the value doesn’t begin with a valid decimal text
    // representation of a number integerValue will return 0.
    if ([_autoPkgRunInterval integerValue] != 0) {
        _defaults.autoPkgRunInterval = [_autoPkgRunInterval integerValue];
    }

    _defaults.SMTPTLSEnabled = [_smtpTLSEnabledButton state];
    NSLog(@"%@ TLS.", _defaults.SMTPTLSEnabled ? @"Enabling" : @"Disabling");

    _defaults.warnBeforeQuittingEnabled = [_warnBeforeQuittingButton state];
    NSLog(@"%@ warning before quitting.", _defaults.warnBeforeQuittingEnabled ? @"Enabling" : @"Disabling");

    _defaults.SMTPAuthenticationEnabled = [_smtpAuthenticationEnabledButton state];
    NSLog(@"%@ SMTP authentication.", _defaults.SMTPAuthenticationEnabled ? @"Enabling" : @"Disabling");

    _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled = [_sendEmailNotificationsWhenNewVersionsAreFoundButton state];
    NSLog(@"%@ email notifications.", _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled ? @"Enabling" : @"Disabling");

    _defaults.checkForNewVersionsOfAppsAutomaticallyEnabled = [_checkForNewVersionsOfAppsAutomaticallyButton state];
    NSLog(@"%@ checking for new apps automatically.", _defaults.checkForNewVersionsOfAppsAutomaticallyEnabled ? @"Enabling" : @"Disabling");

    NSError *error;
    // Store the password used for SMTP authentication in the default keychain
    [SSKeychain setPassword:[_smtpPassword stringValue] forService:kLGApplicationName account:[_smtpUsername stringValue] error:&error];
    if (error) {
        NSLog(@"Error while storing email password in keychain: %@", error);
    } else {
        NSLog(@"Successfully stored email password in keychain.");
    }

    // Synchronize with the defaults database
    [_defaults synchronize];
}

- (void)runCommandAsRoot:(NSString *)command
{
    // Super dirty hack, but way easier than
    // using Authorization Services
    NSDictionary *error = [[NSDictionary alloc] init];
    NSString *script = [NSString stringWithFormat:@"do shell script \"sh -c '%@'\" with administrator privileges", command];
    NSLog(@"AppleScript commands: %@", script);
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    if ([appleScript executeAndReturnError:&error]) {
        NSLog(@"Shell script authorization successful.");
    } else {
        NSLog(@"Shell script authorization failed. Error: %@.", error);
    }
}

- (IBAction)installGit:(id)sender
{
    NSLog(@"Installing Git...");
    
    // Change the button label to "Installing..."
    // and disable the button to prevent multiple clicks
    [_installGitButton setEnabled:NO];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;
    [installer installGit:^(NSError *error) {
        [self stopProgress:error];
        if ([LGHostInfo gitInstalled]) {
            NSLog(@"Git installed successfully.");
            [_installGitButton setEnabled:NO];
            [_gitStatusLabel setStringValue:kLGGitInstalledLabel];
            [_gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
        } else {
            NSLog(@"%@", error.localizedDescription);
            [_installGitButton setEnabled:YES];
            [_gitStatusLabel setStringValue:kLGGitNotInstalledLabel];
            [_gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
        }
    }];
}

- (IBAction)installAutoPkg:(id)sender
{
    NSLog(@"Installing AutoPkg...");
    
    // Disable the button to prevent multiple clicks
    [_installAutoPkgButton setEnabled:NO];
    [self startProgressWithMessage:@"Installing newest version of AutoPkg..."];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;
    [installer installAutoPkg:^(NSError *error) {
        // Update the autoPkgStatus icon and label if it installed successfully
        [self stopProgress:error];
        if ([LGHostInfo autoPkgInstalled]) {
            NSLog(@"AutoPkg installed successfully.");
            [_autoPkgStatusLabel setStringValue:kLGAutoPkgInstalledLabel];
            [_autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
            [_installAutoPkgButton setEnabled:NO];
        } else {
            [_autoPkgStatusLabel setStringValue:kLGAutoPkgNotInstalledLabel];
            [_autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
            [_installAutoPkgButton setEnabled:YES];
        }
    }];
}


#pragma mark - Open Panels
- (NSOpenPanel *)setupOpenPanel
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    [openPanel setCanChooseFiles:NO];
    
    // Enable the selection of directories in the dialog
    [openPanel setCanChooseDirectories:YES];
    
    // Enable the creation of directories in the dialog
    [openPanel setCanCreateDirectories:YES];
    
    // Set the prompt to "Choose" instead of "Open"
    [openPanel setPrompt:@"Choose"];
    
    // Disable multiple selection
    [openPanel setAllowsMultipleSelection:NO];
    
    return openPanel;
}

- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    DLog(@"Opening Munki repo folder...");
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:_defaults.munkiRepo isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:_defaults.munkiRepo];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", _defaults.munkiRepo);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, _defaults.munkiRepo]];
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
    BOOL isDir;
    NSString *autoPkgRecipeReposFolder = [_defaults autoPkgRecipeRepoDir];
    autoPkgRecipeReposFolder = autoPkgRecipeReposFolder ? autoPkgRecipeReposFolder : [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeReposFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeReposFolderURL = [NSURL fileURLWithPath:autoPkgRecipeReposFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeReposFolderURL];
    } else {
        NSLog(@"%@ does not exist.", autoPkgRecipeReposFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeRepos folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeRepos folder located in %@. Please verify that this folder exists.", kLGApplicationName, autoPkgRecipeReposFolder]];
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
    BOOL isDir;
    NSString *autoPkgCacheFolder = [_defaults autoPkgCacheDir];
    autoPkgCacheFolder = autoPkgCacheFolder ? autoPkgCacheFolder : [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgCacheFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgCacheFolderURL = [NSURL fileURLWithPath:autoPkgCacheFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgCacheFolderURL];
    } else {
        NSLog(@"%@ does not exist.", autoPkgCacheFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg Cache folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg Cache folder located in %@. Please verify that this folder exists.", kLGApplicationName, autoPkgCacheFolder]];
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
    BOOL isDir;
    NSString *autoPkgRecipeOverridesFolder = [_defaults autoPkgRecipeOverridesDir];
    autoPkgRecipeOverridesFolder = autoPkgRecipeOverridesFolder ? autoPkgRecipeOverridesFolder : [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeOverridesFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeOverridesFolderURL = [NSURL fileURLWithPath:autoPkgRecipeOverridesFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeOverridesFolderURL];
    } else {
        NSLog(@"%@ does not exist.", autoPkgRecipeOverridesFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeOverrides folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeOverrides folder located in %@. Please verify that this folder exists.", kLGApplicationName, autoPkgRecipeOverridesFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
    }
}


#pragma mark - Choose AutoPkg defaults
- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    DLog(@"Showing dialog for selecting Munki repo location.");
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.munkiRepo ? _defaults.munkiRepo : @"/Users/Shared"]];

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
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeRepoDir ? _defaults.autoPkgRecipeRepoDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg Cache location.");
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgCacheDir ? _defaults.autoPkgCacheDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeOverridesDir ? _defaults.autoPkgRecipeOverridesDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
    [self startProgressWithMessage:@"Updating AutoPkg recipe repos."];
    [self.updateRepoNowButton setEnabled:NO];

    [LGAutoPkgTask repoUpdate:^(NSError *error) {
        [self stopProgress:error];
        [self.updateRepoNowButton setEnabled:YES];
        [self.recipeTableViewHandler reload];
    }];
}

- (IBAction)checkAppsNow:(id)sender
{
    NSString *recipeList = [LGRecipes recipeList];
    [_cancelAutoPkgRunButton setHidden:NO];
    [self startProgressWithMessage:@"Running selected AutoPkg recipes."];
    _task = [[LGAutoPkgTask alloc] init];
    [_task runRecipeList:recipeList
                        progress:^(NSString *message, double taskProgress) {
                            [self updateProgress:message progress:taskProgress];
        }
        reply:^(NSDictionary *report, NSError *error) {
                            [self stopProgress:error];
                            if (report.count || error) {
                                LGEmailer *emailer = [LGEmailer new];
                                [emailer sendEmailForReport:report error:error];
                            }
                            _task = nil;
                            [_cancelAutoPkgRunButton setHidden:YES];
                        }];
}

- (IBAction)cancelAutoPkgRun:(id)sender
{
    if (_task) {
        [_task cancel];
        NSLog(@"AutoPkg task cancelled.");
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
        if ([_autoPkgRunInterval integerValue] != 0) {
            _defaults.autoPkgRunInterval = [_autoPkgRunInterval integerValue];
            [[LGAutoPkgSchedule sharedTimer] configure];
        }
    } else if ([object isEqual:_smtpPassword]) {
        NSError *error;
        [SSKeychain setPassword:[_smtpPassword stringValue] forService:kLGApplicationName account:[_smtpUsername stringValue] error:&error];
        if (error) {
            NSLog(@"Error occurred while storing email password in keychain: %@", error);
        } else {
            NSLog(@"Successfully stored email password in keychain.");
        }
    } else {
        DLog(@"Uncaught controlTextDidEndEditing");
        return;
    }

    // Synchronize with the defaults database
    [_defaults synchronize];

    // This makes the initial config screen not appear automatically on start.
    [_defaults setBool:YES forKey:kLGHasCompletedInitialSetup];
}

#pragma mark - NSTokenFieldDelegate
- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [_defaults setObject:[_smtpTo objectValue] forKey:kLGSMTPTo];
    [_defaults synchronize];
    return tokens;
}

#pragma mark - Tab View Delegate
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([tabViewItem.identifier isEqualTo:@"localFolders"]) {
        [self enableOpenInFinderButtons];
    }
}

#pragma mark - IB Object State Actions
- (void)changeTLSButtonState
{
    if ([_smtpTLSEnabledButton state] == NSOnState) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [_defaults setBool:YES forKey:kLGSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [_defaults setBool:NO forKey:kLGSMTPTLSEnabled];
    }
    [_defaults synchronize];
}

- (void)changeWarnBeforeQuittingButtonState
{
    _defaults.warnBeforeQuittingEnabled = [_warnBeforeQuittingButton state];
    NSLog(@"%@ warning before quitting.", _defaults.warnBeforeQuittingEnabled ? @"Enabling" : @"Disabling");
    [_defaults synchronize];
}

- (void)changeSmtpAuthenticationButtonState
{
    _defaults.SMTPAuthenticationEnabled = [_smtpAuthenticationEnabledButton state];
    NSLog(@"%@ SMTP authentication.", _defaults.SMTPAuthenticationEnabled ? @"Enabling" : @"Disabling");
    [_defaults synchronize];
}

- (void)changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState
{
    _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled = [_sendEmailNotificationsWhenNewVersionsAreFoundButton state];
    NSLog(@"%@ email notifications.", _defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled ? @"Enabling" : @"Disabling");
    [_defaults synchronize];
}

- (void)changeCheckForNewVersionsOfAppsAutomaticallyButtonState
{
    _defaults.checkForNewVersionsOfAppsAutomaticallyEnabled = [_checkForNewVersionsOfAppsAutomaticallyButton state];
    NSLog(@"%@ checking for new apps automatically.", _defaults.checkForNewVersionsOfAppsAutomaticallyEnabled ? @"Enabling" : @"Disabling");
    [[LGAutoPkgSchedule sharedTimer] configure];
}

- (void)changeCheckForRepoUpdatesAutomaticallyButtonState
{
    _defaults.checkForRepoUpdatesAutomaticallyEnabled = [_checkForRepoUpdatesAutomaticallyButton state];
    NSLog(@"%@ checking for repo updates automatically.", _defaults.checkForRepoUpdatesAutomaticallyEnabled ? @"Enabling" : @"Disabling");
    [_defaults synchronize];
}

- (void)enableOpenInFinderButtons
{
    // Enable "Open in Finder" buttons if directories exist
    BOOL isDir;
    
    NSString *autoPkgRecipeReposFolder = [_defaults autoPkgRecipeRepoDir];
    autoPkgRecipeReposFolder = autoPkgRecipeReposFolder ? autoPkgRecipeReposFolder : [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];
    NSString *autoPkgCacheFolder = [_defaults autoPkgCacheDir];
    autoPkgCacheFolder = autoPkgCacheFolder ? autoPkgCacheFolder : [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];
    NSString *autoPkgRecipeOverridesFolder = [_defaults autoPkgRecipeOverridesDir];
    autoPkgRecipeOverridesFolder = autoPkgRecipeOverridesFolder ? autoPkgRecipeOverridesFolder : [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_defaults.munkiRepo isDirectory:&isDir] && isDir) {
        [_openLocalMunkiRepoFolderButton setEnabled:YES];
    } else {
        [_openLocalMunkiRepoFolderButton setEnabled:NO];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgCacheFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgCacheFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgCacheFolderButton setEnabled:NO];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeReposFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeReposFolderButton setEnabled:NO];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeOverridesFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:NO];
    }
}

#pragma mark - Notifications
- (void)autoPkgRunCompleteNotificationRecieved:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationRunAutoPkgComplete
                                                  object:nil];
    
    NSError *error = nil;
    if ([notification.userInfo[kLGNotificationUserInfoError] isKindOfClass:[NSError class]]) {
        error = notification.userInfo[kLGNotificationUserInfoError];
    }
    [self stopProgress:error];
    [self.checkAppsNowButton setEnabled:YES];
}

- (void)updateReposNowCompleteNotificationRecieved:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationUpdateReposComplete
                                                  object:nil];
    // stop progress panel
    NSError *error = nil;
    if ([notification.userInfo[kLGNotificationUserInfoError] isKindOfClass:[NSError class]]) {
        error = notification.userInfo[kLGNotificationUserInfoError];
    }
    
    [self stopProgress:error];
    [self.updateRepoNowButton setEnabled:YES];
}

- (void)updateProgressNotificationReceived:(NSNotification *)notification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_progressIndicator setIndeterminate:NO];
        NSNumber *total = notification.userInfo[kLGNotificationUserInfoTotalRecipeCount];

        if ([notification.userInfo[kLGNotificationUserInfoMessage] isKindOfClass:[NSString class]]) {
            NSString *message = notification.userInfo[kLGNotificationUserInfoMessage];
            _progressDetailsMessage.stringValue = message;
        }
        if (total) {
            [_progressIndicator incrementBy:100/total.doubleValue];
        }
    }];
}

- (void)startProgressNotificationReceived:(NSNotification *)notification
{
    NSString *messge = @"Starting...";
    if ([notification.userInfo[kLGNotificationUserInfoMessage] isKindOfClass:[NSString class]]) {
        messge = notification.userInfo[kLGNotificationUserInfoMessage];
    }
    [self startProgressWithMessage:messge];
}

- (void)stopProgressNotificationReceived:(NSNotification *)notification
{
    NSError *error = nil;
    if ([notification.userInfo[kLGNotificationUserInfoError] isKindOfClass:[NSError class]]) {
        error = notification.userInfo[kLGNotificationUserInfoError];
    }
    [self stopProgress:error];
}

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
        [_testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusUnavailable"]];
    } else if ([status isEqualTo:@YES]) {
        [_testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusAvailable"]];
    } else {
        NSLog(@"Unexpected result for recieved from port test.");
        [_testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusPartiallyAvailable"]];
    }
}


#pragma mark - LGProgressDelegate
- (void)startProgressWithMessage:(NSString *)message
{
    [_menuProgressDelegate startProgressWithMessage:message];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.progressMessage setStringValue:message];
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
    [_menuProgressDelegate stopProgress:error];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.progressPanel orderOut:self];
        [self.progressIndicator setDoubleValue:0.0];
        [self.progressIndicator setIndeterminate:YES];
        [NSApp endSheet:self.progressPanel returnCode:0];
        [self.progressMessage setStringValue:@"Starting..."];
        [self.progressDetailsMessage setStringValue:@""];
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
    [_menuProgressDelegate updateProgress:message progress:progress];
    if (message.length < 100) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.progressIndicator setIndeterminate:NO];
            [self.progressDetailsMessage setStringValue:message];
            [self.progressIndicator setDoubleValue:progress > 5.0 ? progress:5.0 ];
        }];
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

@end
