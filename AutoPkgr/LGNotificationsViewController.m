//
//  LGNotificationsViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
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
//  limitations under the License.//

#import "LGNotificationsViewController.h"
#import "LGPasswords.h"
#import "LGAutoPkgr.h"
#import "LGTestPort.h"
#import "LGEmailer.h"

@interface LGNotificationsViewController ()

@end

@implementation LGNotificationsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    [LGPasswords migrateKeychainIfNeeded:^(NSString *password, NSError *error) {
        if (error) {
            [NSApp presentError:error];
        }

        if (password) {
            _smtpPassword.stringValue = password;
        }
    }];

    [self getKeychainPassword:_smtpPassword];
}

- (NSString *)tabLabel
{
    return @"Alerts & Notifications";
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
                _smtpPassword.safe_stringValue = password;
            }
        }];
    }
}

- (IBAction)updateKeychainPassword:(id)sender
{
    [self savePassword:nil];
}

- (void)savePassword:(void (^)(NSError *error))reply
{
    NSString *account = _smtpUsername.safe_stringValue;
    NSString *password = _smtpPassword.safe_stringValue;

    if (account && password) {
        [LGPasswords savePassword:password forAccount:account reply:^(NSError *error) {
            if (reply) {
                reply(error);
            }

            if (error) {
                if (error.code == errSecAuthFailed || error.code == errSecDuplicateKeychain) {
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

#pragma mark - Email Actions
- (void)testServerPort:(id)sender
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

- (void)sendTestEmail:(id)sender
{
    [self updateKeychainPassword:self];
    // Send a test email notification when the user
    // clicks "Send Test Email"

    DLog(@"'Send Test Email' button clicked.");

    // Handle UI
    //    [_sendTestEmailButton setEnabled:NO]; // disable button
    [_sendTestEmailSpinner setHidden:NO]; // show spinner
    [_sendTestEmailSpinner startAnimation:self]; // animate spinner

    // Setup a completion block
    void (^didComplete)() = ^void(NSError *error) {
//        [_sendTestEmailButton setEnabled:YES]; // enable button
        [_sendTestEmailSpinner setHidden:YES]; // hide spinner
        [_sendTestEmailSpinner stopAnimation:self]; // stop animation

        [self.progressDelegate stopProgress:error];
    };

    [self savePassword:^(NSError *error) {
        // If the save password method has an error stop emailing,
        // The emailer would get the same error.
        if (error) {
            return didComplete(error);
        }

        // Create an instance of the LGEmailer class
        LGEmailer *emailer = [[LGEmailer alloc] init];

        // Set the reply block
        emailer.replyBlock = didComplete;

        // Send the test email.
        [emailer sendTestEmail];
    }];
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

@end
