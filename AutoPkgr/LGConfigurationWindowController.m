//
//  LGConfigurationWindowController.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGConfigurationWindowController.h"
#import "LGConstants.h"
#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "LGUnzipper.h"
#import "LGAutoPkgRunner.h"
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
@synthesize autoPkgCacheFolderButton;
@synthesize autoPkgRecipeReposFolderButton;
@synthesize localMunkiRepoFolderButton;
@synthesize sendTestEmailButton;
@synthesize gitStatusLabel;
@synthesize autoPkgStatusLabel;
@synthesize gitStatusIcon;
@synthesize autoPkgStatusIcon;
@synthesize scheduleMatrix;

static void *XXCheckForNewAppsAutomaticallyEnabledContext = &XXCheckForNewAppsAutomaticallyEnabledContext;
static void *XXCheckForRepoUpdatesAutomaticallyEnabledContext = &XXCheckForRepoUpdatesAutomaticallyEnabledContext;
static void *XXEmailNotificationsEnabledContext = &XXEmailNotificationsEnabledContext;
static void *XXAuthenticationEnabledContext = &XXAuthenticationEnabledContext;


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

- (void)dealloc
{
    [smtpAuthenticationEnabledButton removeObserver:self forKeyPath:@"cell.state" context:XXAuthenticationEnabledContext];
    [sendEmailNotificationsWhenNewVersionsAreFoundButton removeObserver:self forKeyPath:@"cell.state" context:XXEmailNotificationsEnabledContext];
    [checkForNewVersionsOfAppsAutomaticallyButton removeObserver:self forKeyPath:@"cell.state" context:XXCheckForNewAppsAutomaticallyEnabledContext];
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

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
        defaults = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

    // Set matrix size (IB effs this up)
    [scheduleMatrix setIntercellSpacing:NSMakeSize(10.0, 10.5)];

    // Populate the SMTP settings from the user defaults if they exist
    // NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kAutoPkgRunInterval]) {
        [autoPkgRunInterval setIntegerValue:[defaults integerForKey:kAutoPkgRunInterval]];
    }
    if ([defaults objectForKey:kLocalMunkiRepoPath]) {
        [localMunkiRepo setStringValue:[defaults objectForKey:kLocalMunkiRepoPath]];
    }
    if ([defaults objectForKey:kSMTPServer]) {
        [smtpServer setStringValue:[defaults objectForKey:kSMTPServer]];
    }
    if ([defaults objectForKey:kSMTPFrom]) {
        [smtpFrom setStringValue:[defaults objectForKey:kSMTPFrom]];
    }
    if ([defaults integerForKey:kSMTPPort]) {
        [smtpPort setIntegerValue:[defaults integerForKey:kSMTPPort]];
    }
    if ([defaults objectForKey:kSMTPUsername]) {
        [smtpUsername setStringValue:[defaults objectForKey:kSMTPUsername]];
    }
    if ([defaults objectForKey:kSMTPTo]) {
        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in [defaults objectForKey:kSMTPTo]) {
            if (![toAddress isEqual:@""]) {
                [to addObject:toAddress];
            }
        }
        [smtpTo setObjectValue:to];
    }
    if ([defaults objectForKey:kSMTPTLSEnabled]) {
        [smtpTLSEnabledButton setState:[[defaults objectForKey:kSMTPTLSEnabled] boolValue]];
    }
    if ([defaults objectForKey:kSMTPAuthenticationEnabled]) {
        [smtpAuthenticationEnabledButton setState:[[defaults objectForKey:kSMTPAuthenticationEnabled] boolValue]];
    }
    if ([defaults objectForKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled]) {
        [sendEmailNotificationsWhenNewVersionsAreFoundButton setState:[[defaults objectForKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled] boolValue]];
    }
    if ([defaults objectForKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled]) {
        [checkForNewVersionsOfAppsAutomaticallyButton setState:[[defaults objectForKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled] boolValue]];
    }
    if ([defaults objectForKey:kCheckForRepoUpdatesAutomaticallyEnabled]) {
        [checkForRepoUpdatesAutomaticallyButton setState:[[defaults objectForKey:kCheckForRepoUpdatesAutomaticallyEnabled] boolValue]];
    }
    if ([defaults objectForKey:kWarnBeforeQuittingEnabled]) {
        [warnBeforeQuittingButton setState:[[defaults objectForKey:kWarnBeforeQuittingEnabled] boolValue]];
    }

    // Read the SMTP password from the keychain and populate in NSSecureTextField
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:kApplicationName account:[defaults objectForKey:kSMTPUsername] error:&error];

    if ([error code] == SSKeychainErrorNotFound) {
        NSLog(@"Password not found for account %@.", [defaults objectForKey:kSMTPUsername]);
    } else {
        // Only populate the SMTP Password field if the username exists
        if (![[defaults objectForKey:kSMTPUsername] isEqual:@""]) {
            NSLog(@"Retrieved password from keychain for account %@.", [defaults objectForKey:kSMTPUsername]);
            [smtpPassword setStringValue:password];
        }
    }

    // Create an instance of the LGHostInfo class
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];

    if ([hostInfo gitInstalled]) {
        [gitStatusLabel setStringValue:kGitInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:kStatusAvailableImage]];
    } else {
        [gitStatusLabel setStringValue:kGitNotInstalledLabel];
        [gitStatusIcon setImage:[NSImage imageNamed:kStatusUnavailableImage]];
    }

    if ([hostInfo autoPkgInstalled]) {
        [autoPkgStatusLabel setStringValue:kAutoPkgInstalledLabel];
        [autoPkgStatusIcon setImage:[NSImage imageNamed:kStatusAvailableImage]];
    } else {
        [autoPkgStatusLabel setStringValue:kAutoPkgNotInstalledLabel];
        [autoPkgStatusIcon setImage:[NSImage imageNamed:kStatusUnavailableImage]];
    }

    // Enable tools buttons if directories exist
    BOOL isDir;
    NSString *autoPkgCacheFolder = [hostInfo getAutoPkgCacheDir];
    NSString *autoPkgRecipeReposFolder = [hostInfo getAutoPkgRecipeReposDir];
    NSString *localMunkiRepoFolder = [hostInfo getMunkiRepoDir];

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
    
    // First saves the defaults
    [self save];

    // Create an instance of the LGEmailer class
    LGEmailer *emailer = [[LGEmailer alloc] init];

    // Send the test email notification by sending the
    // sendTestEmail message to our object
    [emailer sendTestEmail];
}

- (void)save
{
    [defaults setObject:[smtpServer stringValue] forKey:kSMTPServer];
    [defaults setInteger:[smtpPort integerValue]forKey:kSMTPPort];
    [defaults setObject:[smtpUsername stringValue] forKey:kSMTPUsername];
    [defaults setObject:[smtpFrom stringValue] forKey:kSMTPFrom];
    [defaults setBool:YES forKey:kHasCompletedInitialSetup];
    [defaults setObject:[localMunkiRepo stringValue] forKey:kLocalMunkiRepoPath];
    
    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [defaults setObject:[smtpTo objectValue] forKey:kSMTPTo];

    // If the value doesn’t begin with a valid decimal text
    // representation of a number integerValue will return 0.
    if ([autoPkgRunInterval integerValue] != 0) {
        [defaults setInteger:[autoPkgRunInterval integerValue] forKey:kAutoPkgRunInterval];
    }

    if ([smtpTLSEnabledButton state] == NSOnState) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [defaults setBool:YES forKey:kSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [defaults setBool:NO forKey:kSMTPTLSEnabled];
    }

    if ([warnBeforeQuittingButton state] == NSOnState) {
        NSLog(@"Enabling warning before quitting.");
        [defaults setBool:YES forKey:kWarnBeforeQuittingEnabled];
    } else {
        NSLog(@"Disabling warning before quitting.");
        [defaults setBool:NO forKey:kWarnBeforeQuittingEnabled];
    }

    if ([smtpAuthenticationEnabledButton state] == NSOnState) {
        NSLog(@"Enabling SMTP authentication.");
        [defaults setBool:YES forKey:kSMTPAuthenticationEnabled];
    } else {
        NSLog(@"Disabling SMTP authentication.");
        [defaults setBool:NO forKey:kSMTPAuthenticationEnabled];
    }

    if ([sendEmailNotificationsWhenNewVersionsAreFoundButton state] == NSOnState) {          NSLog(@"Enabling email notifications.");
        [defaults setBool:YES forKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    } else {
        NSLog(@"Disabling email notificaitons.");
        [defaults setBool:NO forKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    }

    if ([checkForNewVersionsOfAppsAutomaticallyButton state] == NSOnState) {          NSLog(@"Enabling checking for new apps automatically.");
        [defaults setBool:YES forKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for new apps automatically.");
        [defaults setBool:NO forKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled];
    }

    if ([checkForRepoUpdatesAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for repo updates automatically.");
        [defaults setBool:YES forKey:kCheckForRepoUpdatesAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for repo updates automatically.");
        [defaults setBool:NO forKey:kCheckForRepoUpdatesAutomaticallyEnabled];
    }

    // Store the password used for SMTP authentication in the default keychain
    [SSKeychain setPassword:[smtpPassword stringValue] forService:kApplicationName account:[smtpUsername stringValue]];
    
    // Synchronize with the defaults database
    [defaults synchronize];

    // Start the AutoPkg run timer if the user enabled it
    [self startAutoPkgRunTimer];
}

- (void)startAutoPkgRunTimer
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner startAutoPkgRunTimer];
}

- (void)runCommandAsRoot:(NSString *)runDirectory command:(NSString *)command
{
    // Get the current working directory
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

    // Change the path to the AutoPkg directory
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:runDirectory];

    // Super dirty hack, but way easier than
    // using Authorization Services
    NSDictionary *error = [[NSDictionary alloc] init];
    NSString *script = [NSString stringWithFormat:@"do shell script \"sh -c '%@'\" with administrator privileges", command];
    NSLog(@"appleScript commands: %@", script);
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    if ([appleScript executeAndReturnError:&error]) {
        NSLog(@"Authorization successful!");
    } else {
        NSLog(@"Authorization failed! Error: %@.", error);
    }

    // Change back to the bundle path when we're done
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:bundlePath];
}

/*
 This should prompt for Xcode CLI tools
 installation on systems without Git.
 */
- (IBAction)installGit:(id)sender
{
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    NSFileHandle *installGitFileHandle = [pipe fileHandleForReading];
    NSString *gitCmd = @"git";

    [task setLaunchPath:gitCmd];
    [task setArguments:[NSArray arrayWithObject:@"--version"]];
    [task setStandardError:pipe];
    [task launch];
    [installGitFileHandle readInBackgroundAndNotify];
}

- (void)downloadAndInstallAutoPkg
{
    LGUnzipper *unzipper = [[LGUnzipper alloc] init];
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];
    NSError *error;

    // Get paths for autopkg.zip and expansion directory
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"autopkg.zip"];
    NSString *autoPkgTmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"autopkg"];

    // Download AutoPkg to temp directory
    NSData *autoPkg = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:kAutoPkgDownloadURL]];
    [autoPkg writeToFile:tmpPath atomically:YES];

    // Unzip AutoPkg from the temp directory
    BOOL autoPkgUnzipped = [unzipper unzip:tmpPath targetDir:autoPkgTmpPath];
    if (autoPkgUnzipped) {
        NSLog(@"Successfully unzipped AutoPkg!");
    } else {
        NSLog(@"Couldn't unzip AutoPkg :(");
    }

    // Get the AutoPkg run directory and script path
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirContents = [fm contentsOfDirectoryAtPath:autoPkgTmpPath error:&error];

    if (error) {
        NSLog(@"An error occurred when attempting to get the contents of the directory %@. Error: %@", autoPkgTmpPath, error);
    }

    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self BEGINSWITH 'autopkg-autopkg-'"];
    NSArray *autoPkgDir = [dirContents filteredArrayUsingPredicate:fltr];
    NSString *autoPkgPath = [autoPkgTmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@", [autoPkgDir objectAtIndex:0]]];
    NSString *autoPkgInstallScriptPath = [NSString stringWithFormat:@"%@/Scripts/install.sh", autoPkgPath];

    // Run the AutoPkg installer script as root
    [self runCommandAsRoot:autoPkgPath command:autoPkgInstallScriptPath];

    // Update the autoPkgStatus icon and label if it installed successfully
    if ([hostInfo autoPkgInstalled]) {
        NSLog(@"AutoPkg installed successfully!");
        [autoPkgStatusLabel setStringValue:kAutoPkgInstalledLabel];
        [autoPkgStatusIcon setImage:[NSImage imageNamed:kStatusAvailableImage]];
    }
}

- (IBAction)installAutoPkg:(id)sender
{
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
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg Cache folder located in %@. Please verify that this folder exists.", kApplicationName, autoPkgCacheFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
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
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeRepos folder located in %@. Please verify that this folder exists.", kApplicationName, autoPkgRecipeReposFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
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
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kApplicationName, localMunkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
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
    // TODO: Success/failure notification
    NSLog(@"Updating AutoPkg recipe repos.");
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner invokeAutoPkgRepoUpdateInBackgroundThread];
}

- (IBAction)checkAppsNow:(id)sender
{
    LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
    [autoPkgRunner invokeAutoPkgInBackgroundThread];
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

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id object = [notification object];
    
    if ([object isEqual:smtpServer]) {
        [defaults setObject:[smtpServer stringValue] forKey:kSMTPServer];
    } else if ([object isEqual:smtpPort]) {
        [defaults setInteger:[smtpPort integerValue] forKey:kSMTPPort];
    } else if ([object isEqual:smtpUsername]) {
        [defaults setObject:[smtpUsername stringValue] forKey:kSMTPUsername];
    } else if ([object isEqual:smtpFrom]) {
        [defaults setObject:[smtpFrom stringValue] forKey:kSMTPFrom];
    } else if ([object isEqual:localMunkiRepo]) {
        [defaults setObject:[localMunkiRepo stringValue] forKey:kLocalMunkiRepoPath];
    } else if ([object isEqual:smtpTo]) {
        // We use objectValue here because objectValue returns an
        // array of strings if the field contains a series of strings
        [defaults setObject:[smtpTo objectValue] forKey:kSMTPTo];
    } else if ([object isEqual:autoPkgRunInterval]) {
        if ([autoPkgRunInterval integerValue] != 0) {
            [defaults setInteger:[autoPkgRunInterval integerValue] forKey:kAutoPkgRunInterval];
            [self startAutoPkgRunTimer];
        }
    } else if ([object isEqual:smtpPassword]) {
        [SSKeychain setPassword:[smtpPassword stringValue] forService:kApplicationName account:[smtpUsername stringValue]];
    } else {
        NSLog(@"Uncaught controlTextDidEndEditing");
        return;
    }
    
    // Synchronize with the defaults database
    [defaults synchronize];
    
    // This makes the initial config screen not appear automatically on start.
    [defaults setBool:YES forKey:kHasCompletedInitialSetup];
}

- (NSArray *)tokenField:(NSTokenField *)tokenField shouldAddObjects:(NSArray *)tokens atIndex:(NSUInteger)index
{
    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [defaults setObject:[smtpTo objectValue] forKey:kSMTPTo];
    [defaults synchronize];
    return tokens;
}

- (void)changeTLSButtonState
{
    if ([smtpTLSEnabledButton state] == NSOnState) {
        // The user wants to enable TLS for this SMTP configuration
        NSLog(@"Enabling TLS.");
        [defaults setBool:YES forKey:kSMTPTLSEnabled];
    } else {
        // The user wants to disable TLS for this SMTP configuration
        NSLog(@"Disabling TLS.");
        [defaults setBool:NO forKey:kSMTPTLSEnabled];
    }
    [defaults synchronize];
}


- (void)changeWarnBeforeQuittingButtonState
{
    if ([warnBeforeQuittingButton state] == NSOnState) {
        NSLog(@"Enabling warning before quitting.");
        [defaults setBool:YES forKey:kWarnBeforeQuittingEnabled];
    } else {
        NSLog(@"Disabling warning before quitting.");
        [defaults setBool:NO forKey:kWarnBeforeQuittingEnabled];
    }
    [defaults synchronize];
}

- (void)changeSmtpAuthenticationButtonState
{
    if ([smtpAuthenticationEnabledButton state] == NSOnState) {
        NSLog(@"Enabling SMTP authentication.");
        [defaults setBool:YES forKey:kSMTPAuthenticationEnabled];
    } else {
        NSLog(@"Disabling SMTP authentication.");
        [defaults setBool:NO forKey:kSMTPAuthenticationEnabled];
    }
    [defaults synchronize];
}

- (void)changeSendEmailNotificationsWhenNewVersionsAreFoundButtonState
{
    if ([sendEmailNotificationsWhenNewVersionsAreFoundButton state] == NSOnState) {
        NSLog(@"Enabling email notifications.");
        [defaults setBool:YES forKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    } else {
        NSLog(@"Disabling email notificaitons.");
        [defaults setBool:NO forKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled];
    }
    [defaults synchronize];
}

- (void)changeCheckForNewVersionsOfAppsAutomaticallyButtonState
{
    if ([checkForNewVersionsOfAppsAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for new apps automatically.");
        [defaults setBool:YES forKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for new apps automatically.");
        [defaults setBool:NO forKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled];
    }
    [defaults synchronize];
    [self startAutoPkgRunTimer];
}

- (void)changeCheckForRepoUpdatesAutomaticallyButtonState
{
    if ([checkForRepoUpdatesAutomaticallyButton state] == NSOnState) {
        NSLog(@"Enabling checking for repo updates automatically.");
        [defaults setBool:YES forKey:kCheckForRepoUpdatesAutomaticallyEnabled];
    } else {
        NSLog(@"Disabling checking for repo updates automatically.");
        [defaults setBool:NO forKey:kCheckForRepoUpdatesAutomaticallyEnabled];
    }
    [defaults synchronize];
}


@end
