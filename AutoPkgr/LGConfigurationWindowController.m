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
#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "LGAutoPkgRunner.h"
#import "LGGitHubJSONLoader.h"
#import "LGVersionComparator.h"
#import "SSKeychain.h"

@interface LGConfigurationWindowController ()

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
@synthesize smtpAuthenticationEnabledButton;
@synthesize smtpTLSEnabledButton;
@synthesize warnBeforeQuittingButton;
@synthesize checkForNewVersionsOfAppsAutomaticallyButton;
@synthesize checkForRepoUpdatesAutomaticallyButton;
@synthesize sendEmailNotificationsWhenNewVersionsAreFoundButton;
@synthesize autoPkgRecipeOverridesFolderButton;
@synthesize autoPkgCacheFolderButton;
@synthesize autoPkgRecipeReposFolderButton;
@synthesize localMunkiRepoFolderButton;
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
        defaults = [NSUserDefaults standardUserDefaults];
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

    // Hide the configuration window
    [self.window orderOut:nil];

    // Populate the preference values from the user defaults if they exist

    if ([defaults objectForKey:kLGAutoPkgRunInterval]) {
        [autoPkgRunInterval setIntegerValue:[defaults integerForKey:kLGAutoPkgRunInterval]];
    }
    if ([defaults objectForKey:kLGAutoPkgMunkiRepoPath]) {
        [localMunkiRepo setStringValue:[defaults objectForKey:kLGAutoPkgMunkiRepoPath]];
    }
    if ([defaults objectForKey:kLGSMTPServer]) {
        [smtpServer setStringValue:[defaults objectForKey:kLGSMTPServer]];
    }
    if ([defaults objectForKey:kLGSMTPFrom]) {
        [smtpFrom setStringValue:[defaults objectForKey:kLGSMTPFrom]];
    }
    if ([defaults integerForKey:kLGSMTPPort]) {
        [smtpPort setIntegerValue:[defaults integerForKey:kLGSMTPPort]];
    }
    if ([defaults objectForKey:kLGSMTPUsername]) {
        [smtpUsername setStringValue:[defaults objectForKey:kLGSMTPUsername]];
    }
    if ([defaults objectForKey:kLGSMTPTo]) {
        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in [defaults objectForKey:kLGSMTPTo]) {
            if (![toAddress isEqual:@""]) {
                [to addObject:toAddress];
            }
        }
        [smtpTo setObjectValue:to];
    }
    if ([defaults objectForKey:kLGSMTPTLSEnabled]) {
        [smtpTLSEnabledButton setState:[[defaults objectForKey:kLGSMTPTLSEnabled] boolValue]];
    }
    if ([defaults objectForKey:kLGSMTPAuthenticationEnabled]) {
        [smtpAuthenticationEnabledButton setState:[[defaults objectForKey:kLGSMTPAuthenticationEnabled] boolValue]];
    }
    if ([defaults objectForKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled]) {
        [sendEmailNotificationsWhenNewVersionsAreFoundButton setState:[[defaults objectForKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled] boolValue]];
    }
    if ([defaults objectForKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled]) {
        [checkForNewVersionsOfAppsAutomaticallyButton setState:[[defaults objectForKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled] boolValue]];
    }
    if ([defaults objectForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled]) {
        [checkForRepoUpdatesAutomaticallyButton setState:[[defaults objectForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled] boolValue]];
    }
    if ([defaults objectForKey:kLGWarnBeforeQuittingEnabled]) {
        [warnBeforeQuittingButton setState:[[defaults objectForKey:kLGWarnBeforeQuittingEnabled] boolValue]];
    }

    // Read the SMTP password from the keychain and populate in
    // NSSecureTextField if it exists
    NSError *error = nil;
    NSString *smtpUsernameString = [defaults objectForKey:kLGSMTPUsername];

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
            if (smtpUsernameString != nil && ![smtpUsernameString isEqual:@""]) {
                NSLog(@"Retrieved password from keychain for account %@.", smtpUsernameString);
                [smtpPassword setStringValue:password];
            }
        }
    }

    // Create an instance of the LGHostInfo class
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];

    if ([hostInfo gitInstalled]) {
        [installGitButton setEnabled:NO];
        [gitStatusLabel setStringValue:kLGGitInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
    } else {
        [installGitButton setEnabled:YES];
        [gitStatusLabel setStringValue:kLGGitNotInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
    }

    if ([hostInfo autoPkgInstalled]) {
        BOOL updateAvailable = [self autoPkgUpdateAvailable];
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

    // Enable tools buttons if directories exist
    BOOL isDir;
    NSString *autoPkgRecipeOverridesFolder = [hostInfo getAutoPkgRecipeOverridesDir];
    NSString *autoPkgCacheFolder = [hostInfo getAutoPkgCacheDir];
    NSString *autoPkgRecipeReposFolder = [hostInfo getAutoPkgRecipeReposDir];
    NSString *localMunkiRepoFolder = [hostInfo getMunkiRepoDir];

    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeOverridesFolder isDirectory:&isDir] && isDir) {
        [autoPkgRecipeOverridesFolderButton setEnabled:YES];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgCacheFolder isDirectory:&isDir] && isDir) {
        [autoPkgCacheFolderButton setEnabled:YES];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:autoPkgRecipeReposFolder isDirectory:&isDir] && isDir) {
        [autoPkgRecipeReposFolderButton setEnabled:YES];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:localMunkiRepoFolder isDirectory:&isDir] && isDir) {
        [localMunkiRepoFolderButton setEnabled:YES];
    }

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
    if (![[smtpServer stringValue] isEqualToString:@""] && [smtpPort integerValue
                                                            ] > 0 ) {

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
    [defaults setObject:[smtpServer stringValue] forKey:kLGSMTPServer];
    [defaults setInteger:[smtpPort integerValue] forKey:kLGSMTPPort];
    [defaults setObject:[smtpUsername stringValue] forKey:kLGSMTPUsername];
    [defaults setObject:[smtpFrom stringValue] forKey:kLGSMTPFrom];
    [defaults setBool:YES forKey:kLGHasCompletedInitialSetup];
    [defaults setObject:[localMunkiRepo stringValue] forKey:kLGAutoPkgMunkiRepoPath];

    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [defaults setObject:[smtpTo objectValue] forKey:kLGSMTPTo];

    // If the value doesn’t begin with a valid decimal text
    // representation of a number integerValue will return 0.
    if ([autoPkgRunInterval integerValue] != 0) {
        [defaults setInteger:[autoPkgRunInterval integerValue] forKey:kLGAutoPkgRunInterval];
    }

    if ([smtpTLSEnabledButton state] == NSOnState) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [defaults setBool:YES forKey:kLGSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [defaults setBool:NO forKey:kLGSMTPTLSEnabled];
    }

    if ([warnBeforeQuittingButton state] == NSOnState) {
        NSLog(@"Enabling warning before quitting.");
        [defaults setBool:YES forKey:kLGWarnBeforeQuittingEnabled];
    } else {
        NSLog(@"Disabling warning before quitting.");
        [defaults setBool:NO forKey:kLGWarnBeforeQuittingEnabled];
    }

    if ([smtpAuthenticationEnabledButton state] == NSOnState) {
        NSLog(@"Enabling SMTP authentication.");
        [defaults setBool:YES forKey:kLGSMTPAuthenticationEnabled];
    } else {
        NSLog(@"Disabling SMTP authentication.");
        [defaults setBool:NO forKey:kLGSMTPAuthenticationEnabled];
    }

    if ([sendEmailNotificationsWhenNewVersionsAreFoundButton state] == NSOnState) {
        NSLog(@"Enabling email notifications.");
        [defaults setBool:YES forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    } else {
        NSLog(@"Disabling email notificaitons.");
        [defaults setBool:NO forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    }

    if ([checkForNewVersionsOfAppsAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for new apps automatically.");
        [defaults setBool:YES forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for new apps automatically.");
        [defaults setBool:NO forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
    }

    if ([checkForRepoUpdatesAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for repo updates automatically.");
        [defaults setBool:YES forKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for repo updates automatically.");
        [defaults setBool:NO forKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
    }

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

    // Start the AutoPkg run timer if the user enabled it
    [self startAutoPkgRunTimer];
}

- (BOOL)autoPkgUpdateAvailable
{
    // TODO: This check shouldn't block the main thread

    // Get the currently installed version of AutoPkg
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSString *installedAutoPkgVersionString = [hostInfo getAutoPkgVersion];
    NSLog(@"Installed version of AutoPkg: %@", installedAutoPkgVersionString);

    // Get the latest version of AutoPkg available on GitHub
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];
    NSString *latestAutoPkgVersionString = [jsonLoader getLatestAutoPkgReleaseVersionNumber];

    // Determine if AutoPkg is up-to-date by comparing the version strings
    LGVersionComparator *vc = [[LGVersionComparator alloc] init];
    BOOL newVersionAvailable = [vc isVersion:latestAutoPkgVersionString greaterThanVersion:installedAutoPkgVersionString];
    if (newVersionAvailable) {
        NSLog(@"A new version of AutoPkg is available. Version %@ is installed and version %@ is available.", installedAutoPkgVersionString, latestAutoPkgVersionString);
        return YES;
    }

    return NO;
}

- (void)startAutoPkgRunTimer
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner startAutoPkgRunTimer];
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
    [installGitButton setTitle:@"Installing..."];
    [installGitButton setEnabled:NO];

    NSTask *task = [[NSTask alloc] init];

    task.launchPath = @"/usr/bin/xcode-select";
    task.arguments = @[@"--install"];
    task.standardError = [NSPipe pipe];

    task.terminationHandler = ^(NSTask *aTask) {
        // TODO: We should probably be installing the official
        // Git PKG rather than dealing with the Xcode CLI tools
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            NSString *alertMessage = @"After the Command Line Tools installation completes, click OK";
            NSAlert *alert = [NSAlert alertWithMessageText:alertMessage
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@""];
            
            if ([alert runModal] == NSAlertDefaultReturn){
                [installGitButton setTitle:@"Install Git"];
                
                LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
                if ([hostInfo gitInstalled]) {
                    [installGitButton setEnabled:NO];
                }else {
                    [installGitButton setTitle:@"Install Git"];
                    [installGitButton setEnabled:YES];
                    alert = [NSAlert alertWithMessageText:@"There was a problem installing Git!"
                                            defaultButton:@"Go get Git!"
                                          alternateButton:@"Cancel"
                                              otherButton:nil
                                informativeTextWithFormat:@"You can try to reinstall from here, or download and install the official version from http://git-scm.com/downloads."];

                    if ( [alert runModal] == NSAlertDefaultReturn) {
                        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://git-scm.com/downloads"]];
                    }
                    
                }
            }
        }];
    };

    [task launch];
}

- (void)downloadAndInstallAutoPkg
{
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];

    // Get the latest AutoPkg PKG download URL
    NSString *downloadURL = [jsonLoader getLatestAutoPkgDownloadURL];

    // Get path for autopkg-x.x.x.pkg
    NSString *autoPkgPkg = [NSTemporaryDirectory() stringByAppendingPathComponent:[downloadURL lastPathComponent]];

    // Download AutoPkg to the temporary directory
    NSData *autoPkg = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:downloadURL]];
    [autoPkg writeToFile:autoPkgPkg atomically:YES];

    // Set the `installer` command
    NSString *command = [NSString stringWithFormat:@"/usr/sbin/installer -pkg %@ -target /", autoPkgPkg];

    // Install the AutoPkg PKG as root
    [self runCommandAsRoot:command];

    // Update the autoPkgStatus icon and label if it installed successfully
    if ([hostInfo autoPkgInstalled]) {
        NSLog(@"AutoPkg installed successfully!");
        [autoPkgStatusLabel setStringValue:kLGAutoPkgInstalledLabel];
        [autoPkgStatusIcon setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
        [installAutoPkgButton setTitle:@"Install AutoPkg"];
        [installAutoPkgButton setEnabled:NO];
    }
}

- (IBAction)installAutoPkg:(id)sender
{
    // Change the button label to "Installing..."
    // and disable the button to prevent multiple clicks
    [installAutoPkgButton setTitle:@"Installing..."];
    [installAutoPkgButton setEnabled:NO];
    [self startProgressWithMessage:@"Installing newest version of AutoPkg"];

    // Download and install AutoPkg on a background thread
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc]
        initWithTarget:self
              selector:@selector(downloadAndInstallAutoPkg)
                object:nil];
    [queue addOperation:operation];
}

- (IBAction)openAutoPkgCacheFolder:(id)sender
{
    BOOL isDir;
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSString *autoPkgCacheFolder = [hostInfo getAutoPkgCacheDir];

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

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    BOOL isDir;
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSString *autoPkgRecipeReposFolder = [hostInfo getAutoPkgRecipeReposDir];

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

- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    BOOL isDir;
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSString *localMunkiRepoFolder = [hostInfo getMunkiRepoDir];

    if ([[NSFileManager defaultManager] fileExistsAtPath:localMunkiRepoFolder isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:localMunkiRepoFolder];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", localMunkiRepoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki Repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, localMunkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.window
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)addAutoPkgRepoURL:(id)sender
{
    // TODO: Input validation + success/failure notification

    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner addAutoPkgRecipeRepo:[repoURLToAdd stringValue]];

    [repoURLToAdd setStringValue:@""];

    [_popRepoTableViewHandler reload];
    [_appTableViewHandler reload];
}

- (IBAction)updateReposNow:(id)sender
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateReposNowCompleteNotificationRecieved:)
                                                 name:kLGNotificationUpdateReposComplete
                                               object:autoPkgRunner];

    // TODO: Success/failure notification
    [self.updateRepoNowButton setEnabled:NO];
    [self startProgressWithMessage:@"Updating AutoPkg recipe repos."];

    NSLog(@"Updating AutoPkg recipe repos.");
    [autoPkgRunner invokeAutoPkgRepoUpdateInBackgroundThread];
}

- (void)updateReposNowCompleteNotificationRecieved:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationUpdateReposComplete
                                                  object:notification.object];
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
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(autoPkgRunCompleteNotificationRecieved:)
                                                 name:kLGNotificationRunAutoPkgComplete
                                               object:autoPkgRunner];

    [self.checkAppsNowButton setEnabled:NO];
    [self startProgressWithMessage:@"Running selected AutoPkg recipes."];

    [autoPkgRunner invokeAutoPkgInBackgroundThread];
}

- (void)autoPkgRunCompleteNotificationRecieved:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kLGNotificationRunAutoPkgComplete
                                                  object:notification.object];

    NSError *error = nil;
    if ([notification.userInfo[kLGNotificationUserInfoError] isKindOfClass:[NSError class]]) {
        error = notification.userInfo[kLGNotificationUserInfoError];
    }
    [self stopProgress:error];
    [self.checkAppsNowButton setEnabled:YES];

}

- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    NSOpenPanel *chooseDialog = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    [chooseDialog setCanChooseFiles:NO];

    // Enable the selection of directories in the dialog
    [chooseDialog setCanChooseDirectories:YES];

    // Enable the creation of directories in the dialog
    [chooseDialog setCanCreateDirectories:YES];

    // Set the prompt to "Choose" instead of "Open"
    [chooseDialog setPrompt:@"Choose"];

    // Disable multiple selection
    [chooseDialog setAllowsMultipleSelection:NO];

    // Set the default directory to /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:@"/Users/Shared"]];

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
                    [autoPkgRunner setLocalMunkiRepoForAutoPkg:urlPath];
                }
            }

        }
    }];
}

- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender
{
    BOOL isDir;
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSString *autoPkgRecipeOverridesFolder = [hostInfo getAutoPkgRecipeOverridesDir];

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

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id object = [notification object];

    if ([object isEqual:smtpServer]) {
        [defaults setObject:[smtpServer stringValue] forKey:kLGSMTPServer];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:smtpPort]) {
        [defaults setInteger:[smtpPort integerValue] forKey:kLGSMTPPort];
        [self testSmtpServerPort:self];
    } else if ([object isEqual:smtpUsername]) {
        [defaults setObject:[smtpUsername stringValue] forKey:kLGSMTPUsername];
    } else if ([object isEqual:smtpFrom]) {
        [defaults setObject:[smtpFrom stringValue] forKey:kLGSMTPFrom];
    } else if ([object isEqual:localMunkiRepo]) {
        [defaults setObject:[localMunkiRepo stringValue] forKey:kLGAutoPkgMunkiRepoPath];
    } else if ([object isEqual:smtpTo]) {
        // We use objectValue here because objectValue returns an
        // array of strings if the field contains a series of strings
        [defaults setObject:[smtpTo objectValue] forKey:kLGSMTPTo];
    } else if ([object isEqual:autoPkgRunInterval]) {
        if ([autoPkgRunInterval integerValue] != 0) {
            [defaults setInteger:[autoPkgRunInterval integerValue] forKey:kLGAutoPkgRunInterval];
            [self startAutoPkgRunTimer];
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
    if ([warnBeforeQuittingButton state] == NSOnState) {
        NSLog(@"Enabling warning before quitting.");
        [defaults setBool:YES forKey:kLGWarnBeforeQuittingEnabled];
    } else {
        NSLog(@"Disabling warning before quitting.");
        [defaults setBool:NO forKey:kLGWarnBeforeQuittingEnabled];
    }
    [defaults synchronize];
}

- (void)changeSmtpAuthenticationButtonState
{
    if ([smtpAuthenticationEnabledButton state] == NSOnState) {
        NSLog(@"Enabling SMTP authentication.");
        [defaults setBool:YES forKey:kLGSMTPAuthenticationEnabled];
    } else {
        NSLog(@"Disabling SMTP authentication.");
        [defaults setBool:NO forKey:kLGSMTPAuthenticationEnabled];
    }
    [defaults synchronize];
}

- (void)changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState
{
    if ([sendEmailNotificationsWhenNewVersionsAreFoundButton state] == NSOnState) {
        NSLog(@"Enabling email notifications.");
        [defaults setBool:YES forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    } else {
        NSLog(@"Disabling email notificaitons.");
        [defaults setBool:NO forKey:kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    }
    [defaults synchronize];
}

- (void)changeCheckForNewVersionsOfAppsAutomaticallyButtonState
{
    if ([checkForNewVersionsOfAppsAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for new apps automatically.");
        [defaults setBool:YES forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for new apps automatically.");
        [defaults setBool:NO forKey:kLGCheckForNewVersionsOfAppsAutomaticallyEnabled];
    }
    [defaults synchronize];
    [self startAutoPkgRunTimer];
}

- (void)changeCheckForRepoUpdatesAutomaticallyButtonState
{
    if ([checkForRepoUpdatesAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for repo updates automatically.");
        [defaults setBool:YES forKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for repo updates automatically.");
        [defaults setBool:NO forKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];
    }
    [defaults synchronize];
}

- (void)updateProgressNotificationReceived:(NSNotification *)notification
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSString *message = @"";
        if ([notification.userInfo[kLGNotificationUserInfoMessage] isKindOfClass:[NSString class]]) {
             message = notification.userInfo[kLGNotificationUserInfoMessage];
        }
        self.progressMessage.stringValue = message;
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
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.progressPanel orderOut:self];
        [NSApp endSheet:self.progressPanel returnCode:0];
        [self.progressMessage setStringValue:@"Starting..."];
        if (error) {
            [[NSAlert alertWithError:error] beginSheetModalForWindow:self.window
                                                       modalDelegate:self
                                                      didEndSelector:nil
                                                         contextInfo:nil];
        }
    }];
}


- (BOOL)windowShouldClose:(id)sender
{
    [self save];

    return YES;
}

@end
