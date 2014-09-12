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
    LGDefaults *defaults;
}

@end

@implementation LGConfigurationWindowController

@synthesize smtpTo;
@synthesize smtpServer;
@synthesize smtpUsername;
@synthesize smtpPassword;
@synthesize smtpPort;
@synthesize smtpFrom;
@synthesize autoPkgRunInterval;
@synthesize repoURLToAdd;
@synthesize localMunkiRepo;
@synthesize autoPkgCacheDir;
@synthesize autoPkgRecipeRepoDir;
@synthesize autoPkgRecipeOverridesDir;
@synthesize smtpAuthenticationEnabledButton;
@synthesize smtpTLSEnabledButton;
@synthesize warnBeforeQuittingButton;
@synthesize checkForNewVersionsOfAppsAutomaticallyButton;
@synthesize checkForRepoUpdatesAutomaticallyButton;
@synthesize sendEmailNotificationsWhenNewVersionsAreFoundButton;
@synthesize openLocalMunkiRepoFolderButton;
@synthesize openAutoPkgRecipeReposFolderButton;
@synthesize openAutoPkgCacheFolderButton;
@synthesize openAutoPkgRecipeOverridesFolderButton;
@synthesize sendTestEmailButton;
@synthesize installGitButton;
@synthesize installAutoPkgButton;
@synthesize gitStatusLabel;
@synthesize autoPkgStatusLabel;
@synthesize gitStatusIcon;
@synthesize autoPkgStatusIcon;
@synthesize sendTestEmailSpinner;
@synthesize testSmtpServerSpinner;
@synthesize testSmtpServerStatus;

static void *XXCheckForNewAppsAutomaticallyEnabledContext = &XXCheckForNewAppsAutomaticallyEnabledContext;
static void *XXCheckForRepoUpdatesAutomaticallyEnabledContext = &XXCheckForRepoUpdatesAutomaticallyEnabledContext;
static void *XXEmailNotificationsEnabledContext = &XXEmailNotificationsEnabledContext;
static void *XXAuthenticationEnabledContext = &XXAuthenticationEnabledContext;

- (void)dealloc
{
    [smtpAuthenticationEnabledButton removeObserver:self forKeyPath:@"cell.state" context:XXAuthenticationEnabledContext];
    [sendEmailNotificationsWhenNewVersionsAreFoundButton removeObserver:self forKeyPath:@"cell.state" context:XXEmailNotificationsEnabledContext];
    [checkForNewVersionsOfAppsAutomaticallyButton removeObserver:self forKeyPath:@"cell.state" context:XXCheckForNewAppsAutomaticallyEnabledContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        defaults = [LGDefaults new];
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
    [smtpAuthenticationEnabledButton addObserver:self
                                      forKeyPath:@"cell.state"
                                         options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                         context:XXAuthenticationEnabledContext];

    [sendEmailNotificationsWhenNewVersionsAreFoundButton addObserver:self
                                                          forKeyPath:@"cell.state"
                                                             options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                                             context:XXEmailNotificationsEnabledContext];

    [checkForNewVersionsOfAppsAutomaticallyButton addObserver:self
                                                   forKeyPath:@"cell.state"
                                                      options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                                      context:XXCheckForNewAppsAutomaticallyEnabledContext];

    // Set up buttons to save their defaults
    [smtpTLSEnabledButton setTarget:self];
    [smtpTLSEnabledButton setAction:@selector(changeTLSButtonState)];
    [warnBeforeQuittingButton setTarget:self];
    [warnBeforeQuittingButton setAction:@selector(changeWarnBeforeQuittingButtonState)];
    [smtpAuthenticationEnabledButton setTarget:self];
    [smtpAuthenticationEnabledButton setAction:@selector(changeSmtpAuthenticationButtonState)];
    [sendEmailNotificationsWhenNewVersionsAreFoundButton setTarget:self];
    [sendEmailNotificationsWhenNewVersionsAreFoundButton setAction:@selector(changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState)];
    [checkForNewVersionsOfAppsAutomaticallyButton setTarget:self];
    [checkForNewVersionsOfAppsAutomaticallyButton setAction:@selector(changeCheckForNewVersionsOfAppsAutomaticallyButtonState)];
    [checkForRepoUpdatesAutomaticallyButton setTarget:self];
    [checkForRepoUpdatesAutomaticallyButton setAction:@selector(changeCheckForRepoUpdatesAutomaticallyButtonState)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == XXAuthenticationEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [smtpUsername setEnabled:YES];
                [smtpPassword setEnabled:YES];
                [smtpTLSEnabledButton setEnabled:YES];
            } else {
                [smtpUsername setEnabled:NO];
                [smtpPassword setEnabled:NO];
                [smtpTLSEnabledButton setEnabled:NO];
            }
        }
    } else if (context == XXEmailNotificationsEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [smtpTo setEnabled:YES];
                [smtpServer setEnabled:YES];
                [smtpUsername setEnabled:YES];
                [smtpPassword setEnabled:YES];
                [smtpPort setEnabled:YES];
                [smtpAuthenticationEnabledButton setEnabled:YES];
                [smtpTLSEnabledButton setEnabled:YES];
                [sendTestEmailButton setEnabled:YES];
                [smtpFrom setEnabled:YES];
            } else {
                [smtpTo setEnabled:NO];
                [smtpServer setEnabled:NO];
                [smtpUsername setEnabled:NO];
                [smtpPassword setEnabled:NO];
                [smtpPort setEnabled:NO];
                [smtpAuthenticationEnabledButton setEnabled:NO];
                [smtpTLSEnabledButton setEnabled:NO];
                [sendTestEmailButton setEnabled:NO];
                [smtpFrom setEnabled:NO];
            }
        }
    } else if (context == XXCheckForNewAppsAutomaticallyEnabledContext) {
        if ([keyPath isEqualToString:@"cell.state"]) {
            if ([[change objectForKey:@"new"] integerValue] == 1) {
                [autoPkgRunInterval setEnabled:YES];
            } else {
                [autoPkgRunInterval setEnabled:NO];
            }
        }
    }
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // Populate the preference values from the user defaults if they exist

    if ([defaults autoPkgRunInterval]) {
        [autoPkgRunInterval setIntegerValue:[defaults autoPkgRunInterval]];
    }
    if ([defaults munkiRepo]) {
        [localMunkiRepo setStringValue:[defaults munkiRepo]];
    }
    if ([defaults autoPkgCacheDir]) {
        [autoPkgCacheDir setStringValue:[defaults autoPkgCacheDir]];
    }
    if ([defaults autoPkgRecipeRepoDir]) {
        [autoPkgRecipeRepoDir setStringValue:[defaults autoPkgRecipeRepoDir]];
    }
    if ([defaults autoPkgRecipeOverridesDir]) {
        [autoPkgRecipeOverridesDir setStringValue:[defaults autoPkgRecipeOverridesDir]];
    }
    if ([defaults SMTPServer]) {
        [smtpServer setStringValue:[defaults SMTPServer]];
    }
    if ([defaults SMTPFrom]) {
        [smtpFrom setStringValue:[defaults SMTPFrom]];
    }
    if ([defaults SMTPPort]) {
        [smtpPort setIntegerValue:[defaults SMTPPort]];
    }
    if ([defaults SMTPUsername]) {
        [smtpUsername setStringValue:[defaults SMTPUsername]];
    }
    if ([defaults SMTPTo]) {
        NSArray *array = [defaults SMTPTo];
        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in array) {
            if (![toAddress isEqual:@""]) {
                [to addObject:toAddress];
            }
        }
        [smtpTo setObjectValue:to];
    }

    [smtpTLSEnabledButton setState:[defaults SMTPTLSEnabled]];

    [smtpAuthenticationEnabledButton setState:[defaults SMTPAuthenticationEnabled]];

    [sendEmailNotificationsWhenNewVersionsAreFoundButton setState:[defaults sendEmailNotificationsWhenNewVersionsAreFoundEnabled]];
    [checkForNewVersionsOfAppsAutomaticallyButton setState:[defaults checkForNewVersionsOfAppsAutomaticallyEnabled]];

    [checkForRepoUpdatesAutomaticallyButton setState:[defaults checkForRepoUpdatesAutomaticallyEnabled]];

    [warnBeforeQuittingButton setState:[defaults warnBeforeQuittingEnabled]];

    // Read the SMTP password from the keychain and populate in
    // NSSecureTextField if it exists
    NSError *error = nil;
    NSString *smtpUsernameString = [defaults SMTPUsername];

    if (smtpUsernameString) {
        NSString *password = [SSKeychain passwordForService:kLGApplicationName
                                                    account:smtpUsernameString
                                                      error:&error];

        if ([error code] == SSKeychainErrorNotFound) {
            NSLog(@"Keychain item not found for account %@.", smtpUsernameString);
        } else if ([error code] == SSKeychainErrorNoPassword) {
            NSLog(@"Found the keychain item for %@ but no password value was returned.", smtpUsernameString);
        } else if (error != nil) {
            NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", smtpUsernameString, [error localizedDescription]);
        } else {
            // Only populate the SMTP Password field if the username exists
            if (smtpUsernameString && password && ![smtpUsernameString isEqual:@""]) {
                NSLog(@"Retrieved password from keychain for account %@.", smtpUsernameString);
                [smtpPassword setStringValue:password];
            }
        }
    }

    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    BOOL autoPkgInstalled = [hostInfo autoPkgInstalled];
    BOOL gitInstalled = [hostInfo gitInstalled];

    if (gitInstalled) {
        [installGitButton setEnabled:NO];
        [gitStatusLabel setStringValue:kLGGitInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
    } else {
        [installGitButton setEnabled:YES];
        [gitStatusLabel setStringValue:kLGGitNotInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
    }

    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        // Since checking for an update can take some time, run it in the background
        if (autoPkgInstalled) {
            BOOL updateAvailable = [hostInfo autoPkgUpdateAvailable];
            if (updateAvailable) {
                [installAutoPkgButton setEnabled:YES];
                [installAutoPkgButton setTitle:@"Update AutoPkg"];
                [autoPkgStatusLabel setStringValue:kLGAutoPkgUpdateAvailableLabel];
                [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusPartiallyAvailable]];
            } else {
                [installAutoPkgButton setEnabled:NO];
                [autoPkgStatusLabel setStringValue:kLGAutoPkgInstalledLabel];
                [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
            }
        } else {
            [installAutoPkgButton setEnabled:YES];
            [autoPkgStatusLabel setStringValue:kLGAutoPkgNotInstalledLabel];
            [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
        }
    }];

    // Update AutoPkg recipe repos when the application launches
    // if the user has enabled automatic repo updates
    if (defaults.checkForRepoUpdatesAutomaticallyEnabled && gitInstalled && autoPkgInstalled) {
        [_updateRepoNowButton setEnabled:NO];
        [_checkAppsNowButton setEnabled:NO];
        [_updateRepoNowButton setTitle:@"Update in Progress..."];
        [LGAutoPkgTask repoUpdate:^(NSError *error) {
            [_updateRepoNowButton setEnabled:YES];
            [_updateRepoNowButton setTitle:@"Update Repos Now"];
            [_checkAppsNowButton setEnabled:YES];
        }];
    }

    // Enable tools buttons if directories exist
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:defaults.munkiRepo isDirectory:&isDir] && isDir) {
        [openLocalMunkiRepoFolderButton setEnabled:YES];
    }

    _popRepoTableViewHandler.progressDelegate = self;

    // Synchronize with the defaults database
    [defaults synchronize];
}

- (IBAction)sendTestEmail:(id)sender
{
    // Send a test email notification when the user
    // clicks "Send Test Email"

    // Handle UI
    [sendTestEmailButton setEnabled:NO]; // disable button
    [sendTestEmailSpinner setHidden:NO]; // show spinner
    [sendTestEmailSpinner startAnimation:self]; // animate spinner
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

- (void)testEmailReceived:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationEmailSent
                                                  object:[notification object]];

    [sendTestEmailButton setEnabled:YES]; // enable button

    // Handle Spinner
    [sendTestEmailSpinner stopAnimation:self]; // stop animation
    [sendTestEmailSpinner setHidden:YES]; // hide spinner

    NSError *e = [[notification userInfo] objectForKey:kLGNotificationUserInfoError]; // pull the error out of the userInfo dictionary
    if (e) {
        NSLog(@"Unable to send test email. Error: %@", e);
        [[NSAlert alertWithError:e] beginSheetModalForWindow:self.window
                                               modalDelegate:self
                                              didEndSelector:nil
                                                 contextInfo:nil];
    }

    [self stopProgress:e];
}

- (void)testSmtpServerPort:(id)sender
{
    if (![[smtpServer stringValue] isEqualToString:@""] && [smtpPort integerValue] > 0) {

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

        // Set up the UI
        [testSmtpServerStatus setHidden:YES];
        [testSmtpServerSpinner setHidden:NO];
        [testSmtpServerSpinner startAnimation:self];

        LGTestPort *tester = [[LGTestPort alloc] init];

        [center addObserver:self
                   selector:@selector(testSmtpServerPortNotificationReceiver:)
                       name:kLGNotificationTestSmtpServerPort
                     object:nil];

        [tester testHost:[NSHost hostWithName:[smtpServer stringValue]]
                withPort:[smtpPort integerValue]];

    } else {
        NSLog(@"Cannot test; either host is blank or port is unreadable.");
    }
}

- (void)testSmtpServerPortNotificationReceiver:(NSNotification *)notification
{
    // Set up the spinner and show the status image
    [testSmtpServerSpinner setHidden:YES];
    [testSmtpServerSpinner stopAnimation:self];
    [testSmtpServerStatus setHidden:NO];

    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationTestSmtpServerPort
                                                  object:nil];

    NSString *status = notification.userInfo[kLGNotificationUserInfoSuccess];
    if ([status isEqualTo:@NO]) {
        [testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusUnavailable"]];
    } else if ([status isEqualTo:@YES]) {
        [testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusAvailable"]];
    } else {
        NSLog(@"Unexpected result for recieved from port test.");
        [testSmtpServerStatus setImage:[NSImage imageNamed:@"NSStatusPartiallyAvailable"]];
    }
}

- (void)save
{
    defaults.SMTPServer = [smtpServer stringValue];
    defaults.SMTPPort = [smtpPort integerValue];
    defaults.SMTPUsername = [smtpUsername stringValue];
    defaults.SMTPFrom = [smtpFrom stringValue];
    defaults.HasCompletedInitialSetup = YES;

    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    defaults.SMTPTo = [smtpTo objectValue];

    // If the value doesn’t begin with a valid decimal text
    // representation of a number integerValue will return 0.
    if ([autoPkgRunInterval integerValue] != 0) {
        defaults.autoPkgRunInterval = [autoPkgRunInterval integerValue];
    }

    defaults.SMTPTLSEnabled = [smtpTLSEnabledButton state];
    NSLog(@"%@ TLS.", defaults.SMTPTLSEnabled ? @"Enabling" : @"Disabling");

    defaults.warnBeforeQuittingEnabled = [warnBeforeQuittingButton state];
    NSLog(@"%@ warning before quitting.", defaults.warnBeforeQuittingEnabled ? @"Enabling" : @"Disabling");

    defaults.SMTPAuthenticationEnabled = [smtpAuthenticationEnabledButton state];
    NSLog(@"%@ SMTP authentication.", defaults.SMTPAuthenticationEnabled ? @"Enabling" : @"Disabling");

    defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled = [sendEmailNotificationsWhenNewVersionsAreFoundButton state];
    NSLog(@"%@ email notifications.", defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled ? @"Enabling" : @"Disabling");

    defaults.checkForNewVersionsOfAppsAutomaticallyEnabled = [checkForNewVersionsOfAppsAutomaticallyButton state];
    NSLog(@"%@ checking for new apps automatically.", defaults.checkForNewVersionsOfAppsAutomaticallyEnabled ? @"Enabling" : @"Disabling");

    NSError *error;
    // Store the password used for SMTP authentication in the default keychain
    [SSKeychain setPassword:[smtpPassword stringValue] forService:kLGApplicationName account:[smtpUsername stringValue] error:&error];
    if (error) {
        NSLog(@"Error while storing e-mail password: %@", error);
    } else {
        NSLog(@"Reset password");
    }

    // Synchronize with the defaults database
    [defaults synchronize];
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
        NSLog(@"Authorization successful!");
    } else {
        NSLog(@"Authorization failed! Error: %@.", error);
    }
}

/*
 This should prompt for Xcode CLI tools
 installation on systems without Git.
 */
- (IBAction)installGit:(id)sender
{
    // Change the button label to "Installing..."
    // and disable the button to prevent multiple clicks
    [installGitButton setEnabled:NO];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;
    [installer installGit:^(NSError *error) {
        LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
        [self stopProgress:error];
        if ([hostInfo gitInstalled]) {
            NSLog(@"Git installed successfully!");
            [installGitButton setEnabled:NO];
            [gitStatusLabel setStringValue:kLGGitInstalledLabel];
            [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
        } else {
            NSLog(@"%@",error.localizedDescription);
            [installGitButton setEnabled:YES];
            [gitStatusLabel setStringValue:kLGGitNotInstalledLabel];
            [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
        }
    }];
}

- (IBAction)installAutoPkg:(id)sender
{
    // and disable the button to prevent multiple clicks
    [installAutoPkgButton setEnabled:NO];
    [self startProgressWithMessage:@"Installing newest version of AutoPkg"];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;
    [installer installAutoPkg:^(NSError *error) {
        // Update the autoPkgStatus icon and label if it installed successfully
        LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
        [self stopProgress:error];
        if ([hostInfo autoPkgInstalled]) {
            NSLog(@"AutoPkg installed successfully!");
            [autoPkgStatusLabel setStringValue:kLGAutoPkgInstalledLabel];
            [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
            [installAutoPkgButton setEnabled:NO];
        }else{
            [autoPkgStatusLabel setStringValue:kLGAutoPkgNotInstalledLabel];
            [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
            [installAutoPkgButton setEnabled:YES];
        }
    }];
}

- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:defaults.munkiRepo isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:defaults.munkiRepo];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", defaults.munkiRepo);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki Repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, defaults.munkiRepo]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    BOOL isDir;
    NSString *autoPkgRecipeReposFolder = [defaults autoPkgRecipeRepoDir];
    autoPkgRecipeReposFolder = autoPkgRecipeReposFolder ? autoPkgRecipeReposFolder : [@"~/Library/AutoPkg" stringByExpandingTildeInPath];

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
    BOOL isDir;
    NSString *autoPkgCacheFolder = [defaults autoPkgCacheDir];
    autoPkgCacheFolder = autoPkgCacheFolder ? autoPkgCacheFolder : [@"~/Library/AutoPkg" stringByExpandingTildeInPath];

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
    BOOL isDir;
    NSString *autoPkgRecipeOverridesFolder = [defaults autoPkgRecipeOverridesDir];
    autoPkgRecipeOverridesFolder = autoPkgRecipeOverridesFolder ? autoPkgRecipeOverridesFolder : [@"~/Library/AutoPkg" stringByExpandingTildeInPath];

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
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:defaults.munkiRepo ? defaults.munkiRepo : @"/Users/Shared"]];

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
                    NSString *urlPath = [url path];
                    [localMunkiRepo setStringValue:urlPath];
                    [openLocalMunkiRepoFolderButton setEnabled:YES];
                    defaults.munkiRepo = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:defaults.autoPkgRecipeRepoDir ? defaults.autoPkgRecipeRepoDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
                    NSString *urlPath = [url path];
                    [autoPkgRecipeRepoDir setStringValue:urlPath];
                    [openAutoPkgRecipeReposFolderButton setEnabled:YES];
                    defaults.autoPkgRecipeRepoDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:defaults.autoPkgCacheDir ? defaults.autoPkgCacheDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
                    NSString *urlPath = [url path];
                    [autoPkgCacheDir setStringValue:urlPath];
                    [openAutoPkgCacheFolderButton setEnabled:YES];
                    defaults.autoPkgCacheDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    NSOpenPanel *chooseDialog = [self setupOpenPanel];

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:defaults.autoPkgRecipeOverridesDir ? defaults.autoPkgRecipeOverridesDir : [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

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
                    NSString *urlPath = [url path];
                    [autoPkgRecipeOverridesDir setStringValue:urlPath];
                    [openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
                    defaults.autoPkgRecipeOverridesDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)addAutoPkgRepoURL:(id)sender
{
    // TODO: Input validation + success/failure notification
    NSString *repo = [repoURLToAdd stringValue];
    [self startProgressWithMessage:[NSString stringWithFormat:@"Adding %@", repo]];

    [LGAutoPkgTask repoAdd:repo reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self stopProgress:error];
            [_popRepoTableViewHandler reload];
            [_appTableViewHandler reload];
        }];
    }];
    [repoURLToAdd setStringValue:@""];
}

- (IBAction)updateReposNow:(id)sender
{
    [self startProgressWithMessage:@"Updating AutoPkg recipe repos."];
    [self.updateRepoNowButton setEnabled:NO];

    [LGAutoPkgTask repoUpdate:^(NSError *error) {
        [self stopProgress:error];
        [self.updateRepoNowButton setEnabled:YES];
    }];
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

- (IBAction)checkAppsNow:(id)sender
{
    NSString *recipeList = [LGApplications recipeList];

    [self startProgressWithMessage:@"Running selected AutoPkg recipes."];
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

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id object = [notification object];

    if ([object isEqual:smtpServer]) {
        defaults.SMTPServer = [smtpServer stringValue];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:smtpPort]) {
        defaults.SMTPPort = [smtpPort integerValue];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:smtpUsername]) {
        defaults.SMTPUsername = [smtpUsername stringValue];
    } else if ([object isEqual:smtpFrom]) {
        defaults.SMTPFrom = [smtpFrom stringValue];
    } else if ([object isEqual:localMunkiRepo]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[localMunkiRepo stringValue] isEqualToString:@""] ? nil : [localMunkiRepo stringValue];
        defaults.munkiRepo = value;
    } else if ([object isEqual:autoPkgRecipeOverridesDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[autoPkgRecipeOverridesDir stringValue] isEqualToString:@""] ? nil : [autoPkgRecipeOverridesDir stringValue];
        defaults.autoPkgRecipeOverridesDir = value;
    } else if ([object isEqual:autoPkgRecipeRepoDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[autoPkgRecipeRepoDir stringValue] isEqualToString:@""] ? nil : [autoPkgRecipeRepoDir stringValue];
        defaults.autoPkgRecipeRepoDir = value;
    } else if ([object isEqual:autoPkgCacheDir]) {
        // Pass nil here if string is "" so it removes the key from the defaults
        NSString *value = [[autoPkgCacheDir stringValue] isEqualToString:@""] ? nil : [autoPkgCacheDir stringValue];
        defaults.autoPkgCacheDir = value;
    } else if ([object isEqual:smtpTo]) {
        // We use objectValue here because objectValue returns an
        // array of strings if the field contains a series of strings
        defaults.SMTPTo = [smtpTo objectValue];
    } else if ([object isEqual:autoPkgRunInterval]) {
        if ([autoPkgRunInterval integerValue] != 0) {
            defaults.autoPkgRunInterval = [autoPkgRunInterval integerValue];
            [[LGAutoPkgSchedule sharedTimer] configure];
        }
    } else if ([object isEqual:smtpPassword]) {
        NSError *error;
        [SSKeychain setPassword:[smtpPassword stringValue] forService:kLGApplicationName account:[smtpUsername stringValue] error:&error];
        if (error) {
            NSLog(@"Error while storing e-mail password: %@", error);
        } else {
            NSLog(@"Reset password");
        }
    } else {
        NSLog(@"Uncaught controlTextDidEndEditing");
        return;
    }

    // Synchronize with the defaults database
    [defaults synchronize];

    // This makes the initial config screen not appear automatically on start.
    [defaults setBool:YES forKey:kLGHasCompletedInitialSetup];
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [defaults setObject:[smtpTo objectValue] forKey:kLGSMTPTo];
    [defaults synchronize];
    return tokens;
}

- (void)changeTLSButtonState
{
    if ([smtpTLSEnabledButton state] == NSOnState) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [defaults setBool:YES forKey:kLGSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [defaults setBool:NO forKey:kLGSMTPTLSEnabled];
    }
    [defaults synchronize];
}

- (void)changeWarnBeforeQuittingButtonState
{
    defaults.warnBeforeQuittingEnabled = [warnBeforeQuittingButton state];
    NSLog(@"%@ warning before quitting.", defaults.warnBeforeQuittingEnabled ? @"Enabling" : @"Disabling");
    [defaults synchronize];
}

- (void)changeSmtpAuthenticationButtonState
{
    defaults.SMTPAuthenticationEnabled = [smtpAuthenticationEnabledButton state];
    NSLog(@"%@ SMTP authentication.", defaults.SMTPAuthenticationEnabled ? @"Enabling" : @"Disabling");
    [defaults synchronize];
}

- (void)changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState
{
    defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled = [sendEmailNotificationsWhenNewVersionsAreFoundButton state];
    NSLog(@"%@  email notifications.", defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled ? @"Enabling" : @"Disabling");
    [defaults synchronize];
}

- (void)changeCheckForNewVersionsOfAppsAutomaticallyButtonState
{
    defaults.checkForNewVersionsOfAppsAutomaticallyEnabled = [checkForNewVersionsOfAppsAutomaticallyButton state];
    NSLog(@"%@ checking for new apps automatically.", defaults.checkForNewVersionsOfAppsAutomaticallyEnabled ? @"Enabling" : @"Disabling");
    [[LGAutoPkgSchedule sharedTimer] configure];
}

- (void)changeCheckForRepoUpdatesAutomaticallyButtonState
{
    defaults.checkForRepoUpdatesAutomaticallyEnabled = [checkForRepoUpdatesAutomaticallyButton state];
    NSLog(@"%@ checking for repo updates automatically.", defaults.checkForRepoUpdatesAutomaticallyEnabled ? @"Enabling" : @"Disabling");
    [defaults synchronize];
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

- (void)didEndWithPreferenceRepairRequest:(NSAlert *)alert returnCode:(NSInteger)returnCode
{
    if (returnCode == NSAlertSecondButtonReturn) {
        NSError *error;
        NSInteger neededFixing;
        BOOL rc = [LGDefaults fixRelativePathsInAutoPkgDefaults:&error neededFixing:&neededFixing];
        if (neededFixing > 0) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = [NSString stringWithFormat:@"%ld problems were found in the AutoPkg preference file", neededFixing];
            alert.informativeText = rc ? @"AutoPkgr was able to repair the preference file. No further action is required." : @"AutoPkgr could not repair the preference file. If the problem persists open an issue on the AutoPkgr GitHub page.";
            [alert beginSheetModalForWindow:self.window
                              modalDelegate:self
                             didEndSelector:nil
                                contextInfo:nil];

        } else {
            DLog(@"No problems were detected in the AutoPkg preference file.");
        }
    }
}

- (BOOL)windowShouldClose:(id)sender
{
    [self save];

    return YES;
}

@end
