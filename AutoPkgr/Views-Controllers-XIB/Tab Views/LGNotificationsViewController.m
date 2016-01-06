//
//  LGNotificationsViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGNotificationsViewController.h"
#import "LGAutoPkgr.h"
#import "LGPasswords.h"
#import "LGTestPort.h"
#import "LGEmailNotification.h"
#import "LGSlackNotification.h"
#import "LGHipChatNotification.h"

#import "LGBaseNotificationServiceViewController.h"
#import "LGNotificationServiceWindowController.h"
#import "LGTemplateRenderWindowController.h"
#import "LGSelectNotificationsWindowController.h"

@interface LGNotificationsViewController ()
#pragma mark - Email
#pragma mark-- Outlets --

@property (weak) IBOutlet NSTextField *smtpServer;
@property (weak) IBOutlet NSTextField *smtpPort;

@property (weak) IBOutlet NSTextField *smtpUsername;
@property (weak) IBOutlet NSSecureTextField *smtpPassword;

// Status icons
@property (weak) IBOutlet NSImageView *testSmtpServerStatus;

// Spinners
@property (weak) IBOutlet NSProgressIndicator *sendTestEmailSpinner;
@property (weak) IBOutlet NSProgressIndicator *testSmtpServerSpinner;

#pragma mark-- IBActions --
- (IBAction)sendTestEmail:(id)sender;
- (IBAction)testServerPort:(id)sender;

- (IBAction)getKeychainPassword:(NSTextField *)sender;
- (IBAction)updateKeychainPassword:(id)sender;

#pragma mark Other Services
#pragma mark-- Outletes ---

@property (weak) IBOutlet NSButton *configureSlackButton;
@property (weak) IBOutlet NSButton *configureHipChatButton;

#pragma mark-- IBActions
- (IBAction)configure:(NSButton *)sender;

@end

#pragma mark - LGNotificationsViewController
@implementation LGNotificationsViewController {
    LGNotificationServiceWindowController *_serviceWindow;
    LGTemplateRenderWindowController *_templateRenderWindow;
    LGSelectNotificationsWindowController *_flagConfigureWindow;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    self.configureHipChatButton.action = @selector(configure:);
    self.configureHipChatButton.target = self;
    self.configureHipChatButton.identifier = NSStringFromClass([LGHipChatNotification class]);

    self.configureSlackButton.action = @selector(configure:);
    self.configureSlackButton.target = self;
    self.configureSlackButton.identifier = NSStringFromClass([LGSlackNotification class]);

    self.configureSlackButton.wantsLayer = YES;
    self.configureSlackButton.animator.alphaValue = 1.0;

    [LGPasswords migrateKeychainIfNeeded:^(NSString *password, NSError *error) {
        if (error) {
            [NSApp presentError:error];
        }

        if (password) {
            _smtpPassword.stringValue = password;
        }
    }];

    [self getKeychainPassword:_smtpPassword];
    [LGPasswords lockKeychain];
}

- (NSString *)tabLabel
{
    return NSLocalizedString(@"Notifications", @"Tab label");
}

#pragma mark - Open Config Panel
- (IBAction)configure:(NSButton *)sender
{
    // Handle first time checkboxes...
    if (sender.state) {
        BOOL configured = NO;
        if ([sender.identifier isEqualToString:@"enableSlackCheckBox"]) {
            configured = [[LGDefaults standardUserDefaults] boolForKey:@"SlackConfigured"];
            if (!configured) {
                [self configure:self.configureSlackButton];
                [[LGDefaults standardUserDefaults] setBool:YES forKey:@"SlackConfigured"];
            }
        } else if ([sender.identifier isEqualToString:@"enableHipChatCheckBox"]) {
            configured = [[LGDefaults standardUserDefaults] boolForKey:@"HipChatConfigured"];
            if (!configured) {
                [self configure:self.configureHipChatButton];
                [[LGDefaults standardUserDefaults] setBool:YES forKey:@"HipChatConfigured"];
            }
        }
    }

    Class viewClass = NSClassFromString([sender.identifier stringByAppendingString:@"View"]);
    Class serviceClass = NSClassFromString(sender.identifier);

    if (serviceClass && viewClass) {
        id<LGNotificationServiceProtocol> service = [[serviceClass alloc] init];
        LGBaseNotificationServiceViewController *serviceView = [[viewClass alloc] initWithNotificationService:service];

        _serviceWindow = [[LGNotificationServiceWindowController alloc] initWithViewController:serviceView];

        [_serviceWindow openSheetOnWindow:self.modalWindow complete:^(LGWindowController *windowController) {
            NSString *enabledKey = nil;
            if (serviceClass == [LGSlackNotification class]) {
                enabledKey = @"Slack";
            } else if (serviceClass == [LGHipChatNotification class]){
                enabledKey = @"HipChat";
            }
            if (enabledKey.length) {
                id controller = (LGBaseNotificationServiceViewController *)_serviceWindow.viewController;
                if([controller respondsToSelector:@selector(didConfigure)] && ![controller didConfigure]){
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[enabledKey stringByAppendingString:@"NotificationsEnabled"]];
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[enabledKey stringByAppendingString:@"Configured"]];
                }
            }
            _serviceWindow = nil;
        }];
    }
}

- (IBAction)configureNotificationsFlags:(id)sender {
    _flagConfigureWindow = [[LGSelectNotificationsWindowController alloc] init];
    [_flagConfigureWindow openSheetOnWindow:self.modalWindow complete:^(LGWindowController *windowController) {
        _flagConfigureWindow = nil;
    }];
}

- (IBAction)openTemplateEditor:(id)sender
{
    _templateRenderWindow = [[LGTemplateRenderWindowController alloc] init];
    [_templateRenderWindow open:^(LGWindowController *renderer){
        _templateRenderWindow = nil;
    }];
}

#pragma mark - Keychain Actions
- (void)getKeychainPassword:(NSTextField *)sender
{
    [LGEmailNotification infoFromKeychain:^(NSString *infoOrPassword, NSError *error) {
        if (error) {
            NSLog(@"Error getting password for %@ [%ld]: %@", [LGEmailNotification account], error.code, error.localizedDescription);
        } else {
            _smtpPassword.safe_stringValue = infoOrPassword;
        }
    }];
}

- (IBAction)updateKeychainPassword:(id)sender
{
    [self savePassword:nil];
}

- (void)savePassword:(void (^)(NSError *error))reply
{
    NSString *account = _smtpUsername.safe_stringValue;
    NSString *password = _smtpPassword.safe_stringValue;

    if (account && [LGEmailNotification storesInfoInKeychain]) {
        [LGEmailNotification saveInfoToKeychain:password reply:^(NSError *error) {
            if (reply) {
                reply(error);
            }
            if (error) {
                if (error.code == errSecAuthFailed || error.code == errSecDuplicateKeychain) {
                    [LGPasswords resetKeychainPrompt:^(NSError *error) {
                        if (!error) {
                            [self updateKeychainPassword:nil];
                        } else {
                            NSLog(@"Error resetting password [%ld]: %@", error.code, error.localizedDescription);
                        }
                    }];
                } else {
                    NSLog(@"Error setting password [%ld]: %@", error.code, error.localizedDescription);
                }
            }
        }];
    } else {
        if(reply){
            reply(nil);
        }
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

    DevLog(@"'Send Test Email' button clicked.");

    // Handle UI
    [sender setEnabled:NO]; // disable button
    [_sendTestEmailSpinner setHidden:NO]; // show spinner
    [_sendTestEmailSpinner startAnimation:self]; // animate spinner

    // Setup a completion block
    void (^didComplete)(NSError *) = ^void(NSError *error) {
        [sender setEnabled:YES]; // enable button
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
        LGEmailNotification *emailer = [[LGEmailNotification alloc] init];
        [emailer sendTest:didComplete];
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
