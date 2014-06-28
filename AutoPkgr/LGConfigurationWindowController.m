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
#import "SSKeychain.h"

@interface LGConfigurationWindowController ()

@end

@implementation LGConfigurationWindowController

@synthesize smtpTo;
@synthesize smtpServer;
@synthesize smtpUsername;
@synthesize smtpPassword;
@synthesize smtpPort;
@synthesize smtpAuthenticationEnabledButton;
@synthesize smtpTLSEnabledButton;
@synthesize warnBeforeQuittingButton;

- (void)awakeFromNib
{
    // This is for the token field support
    [self.smtpTo setDelegate:self];

    [smtpAuthenticationEnabledButton addObserver:self
                                      forKeyPath:@"cell.state"
                                         options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                         context:NULL];
}

- (void)dealloc
{
    [smtpAuthenticationEnabledButton removeObserver:self forKeyPath:@"cell.state"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
//    NSLog(@"Keypath: %@", keyPath);
//    NSLog(@"ofObject: %@", object);
//    NSLog(@"change: %@", change);
    if ([keyPath isEqualToString:@"cell.state"]) {
        if ([[change objectForKey:@"new"] integerValue] == 1) {
            [smtpUsername setEnabled:YES];
            [smtpPassword setEnabled:YES];
        } else {
            [smtpUsername setEnabled:NO];
            [smtpPassword setEnabled:NO];
        }
    }
}

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

    // Populate the SMTP settings from the user defaults if they exist
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kSMTPServer]) {
        [smtpServer setStringValue:[defaults objectForKey:kSMTPServer]];
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

    // Set the SMTPFrom key to shortname@hostname
    [defaults setObject:[hostInfo getUserAtHostName] forKey:kSMTPFrom];

    // Synchronize with the defaults database
    [defaults synchronize];
}

- (IBAction)sendTestEmail:(id)sender {
    // Send a test email notification when the user
    // clicks "Send Test Email"

    // Create an instance of the LGEmailer class
    LGEmailer *emailer = [[LGEmailer alloc] init];

    // Send the test email notification by sending the
    // sendTestEmail message to our object
    [emailer sendTestEmail];
}

- (IBAction)saveAndClose:(id)sender {
    // Store the SMTP settings in NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Create an instance of the LGHostInfo class
    LGHostInfo *hostInfo = [[LGHostInfo alloc] init];

    [defaults setObject:[smtpServer stringValue] forKey:kSMTPServer];
    [defaults setInteger:[smtpPort integerValue]forKey:kSMTPPort];
    [defaults setObject:[smtpUsername stringValue] forKey:kSMTPUsername];
    [defaults setObject:[hostInfo getUserAtHostName] forKey:kSMTPFrom];
    [defaults setBool:YES forKey:kHasCompletedInitialSetup];
    // We use objectValue here because objectValue returns an
    // array of strings if the field contains a series of strings
    [defaults setObject:[smtpTo objectValue] forKey:kSMTPTo];

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

    // Store the password used for SMTP authentication in the default keychain
    [SSKeychain setPassword:[smtpPassword stringValue] forService:kApplicationName account:[smtpUsername stringValue]];

    // Synchronize with the defaults database
    [defaults synchronize];

    // Close the window
    [self close];
}

@end
