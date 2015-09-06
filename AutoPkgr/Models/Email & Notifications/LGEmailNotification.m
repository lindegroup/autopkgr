//
//  LGEmailNotification.m
//  AutoPkgr
//
//  Copyright 2015 The Linde Group, Inc.
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

#import "LGEmailNotification.h"
#import "LGAutoPkgr.h"
#import "LGServerCredentials.h"
#import "LGPasswords.h"
#import "LGUserNotification.h"

#import <MailCore/MailCore.h>

@implementation LGEmailNotification {
    LGDefaults *_defaults;
}

#pragma mark - Protocol Conforming
+ (NSString *)serviceDescription
{
    return NSLocalizedString(@"AutoPkgr Emailer", @"Email notification service description");
}

+ (BOOL)reportsIntegrations
{
    return YES;
}

+ (BOOL)isEnabled
{
    return [[LGDefaults standardUserDefaults] sendEmailNotificationsWhenNewVersionsAreFoundEnabled];
}

+ (BOOL)storesInfoInKeychain
{
    return [[LGDefaults standardUserDefaults] SMTPAuthenticationEnabled];
}

+ (NSString *)account
{
    return [[LGDefaults standardUserDefaults] SMTPUsername];
}

+ (NSString *)keychainServiceLabel
{
    return [kLGApplicationName stringByAppendingString:@" Email Password"];
}

+ (NSString *)keychainServiceDescription
{
    return kLGAutoPkgrPreferenceDomain;
}

#pragma mark - Init
- (instancetype)init
{
    if (self = [super init]) {
        _defaults = [LGDefaults standardUserDefaults];
    };
    return self;
}

#pragma mark - Send
- (void)send:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSAssert(self.notificatonComplete, @"A completion block must be set for %@", self);

    NSString *subject = self.report.emailSubjectString;
    NSString *message = self.report.emailMessageString;

    // Send the email.
    [self sendEmailNotification:subject message:message test:NO];
}

- (void)sendTest:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }

    NSString *subject = NSLocalizedString(@"Test notification from AutoPkgr", nil);
    NSString *message = NSLocalizedString(@"This is a test notification from <strong>AutoPkgr</strong>.", @"html test email body");

    // Send the email/
    [self sendEmailNotification:subject message:message test:YES];
}

#pragma mark - Credentials
- (void)getMailCredentials:(void (^)(LGHTTPCredential *, NSError *))reply
{
    /* This sends back a credential object with three properties
     * 1) Server Name
     * 2) User Name, if authentication is enabled
     * 3) Password, if authentication is enabled */
    LGHTTPCredential *credential = [[LGHTTPCredential alloc] init];

    credential.server = _defaults.SMTPServer;
    credential.port = _defaults.SMTPPort;

    if (_defaults.SMTPAuthenticationEnabled) {
        [[self class] infoFromKeychain:^(NSString *infoOrPassword, NSError *error) {
            credential.user = [[self class] account];
            credential.password = infoOrPassword ?: @"";
            reply(credential, error);
        }];
    } else {
        reply(credential, nil);
    }
}

- (NSArray *)smtpTo
{
    NSMutableArray *to = [[NSMutableArray alloc] init];
    for (NSString *toAddress in _defaults.SMTPTo) {
        if (toAddress.length) {
            [to addObject:[MCOAddress addressWithMailbox:toAddress]];
        }
    }
    return to;
}

- (MCOAddress *)smtpFrom
{
    return [MCOAddress addressWithDisplayName:@"AutoPkgr Notification"
                                      mailbox:_defaults.SMTPFrom ?: @"AutoPkgr"];
}

#pragma mark - Primary sending method
- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message test:(BOOL)test
{

    void (^didCompleteSendOperation)(NSError *) = ^(NSError *error) {
        if (error) {
            NSLog(@"Error sending email: %@", error);
        }
        if (self.notificatonComplete) {
            self.notificatonComplete(error);
        }
    };

    [self getMailCredentials:^(LGHTTPCredential *credential, NSError *error) {
        if (error) {
            /* And error here means there was a problem getting the password */
            return didCompleteSendOperation(error);
        }

        // Build the message.
        MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];

        builder.header.from = [self smtpFrom];
        builder.header.to = [self smtpTo];
        builder.header.subject = subject;
        builder.htmlBody = message;

        /* Configure the session details */
        MCOSMTPSession *session = [[MCOSMTPSession alloc] init];
        session.hostname = credential.server;
        session.port = (int)credential.port;
        session.timeout = 15;

        if (credential.user && credential.password) {
            session.username = credential.user;
            session.password = credential.password;
        }

        if (_defaults.SMTPTLSEnabled) {
            DLog(@"SSL/TLS is enabled for %@.", _defaults.SMTPServer);
            /* If the SMTP port is 465, use MCOConnectionTypeTLS.
             * Otherwise use MCOConnectionTypeStartTLS. */
            if (session.port == 465) {
                session.connectionType = MCOConnectionTypeTLS;
            } else {
                session.connectionType = MCOConnectionTypeStartTLS;
            }
        } else {
            DLog(@"SSL/TLS is _not_ enabled for %@.", _defaults.SMTPServer);
            session.connectionType = MCOConnectionTypeClear;
        }

        MCOSMTPSendOperation *sendOperation = [session sendOperationWithData:builder.data];
        [sendOperation start:^(NSError *error) {
            if (test) {
                [LGUserNotification sendNotificationOfTestEmailSuccess:error ? NO:YES error:error];
            }

            // Call did complete operation.
            didCompleteSendOperation(error);
        }];
    }];
}

@end
