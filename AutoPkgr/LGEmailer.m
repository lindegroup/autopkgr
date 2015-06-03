//
//  LGEmailer.m
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

#import "LGEmailer.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGPasswords.h"
#import "LGToolManager.h"
#import "LGUserNotifications.h"
#import "LGAutoPkgReport.h"

@implementation LGEmailer

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message
{
    LGDefaults *defaults = [[LGDefaults alloc] init];

    if (defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled) {

        // Transform the raw values.
        NSString *fullSubject = [NSString stringWithFormat:@"%@ on %@", subject, [[NSHost currentHost] localizedName]];
        NSString *from = defaults.SMTPFrom ?: @"AutoPkgr";

        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in defaults.SMTPTo) {
            if (toAddress.length) {
                [to addObject:[MCOAddress addressWithMailbox:toAddress]];
            }
        }

        // Build the message.
        MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];

        builder.header.from = [MCOAddress addressWithDisplayName:@"AutoPkgr Notification"
                                                         mailbox:from];
        builder.header.to = to;
        builder.header.subject = fullSubject;
        builder.htmlBody = message;


        // Configure the session details
        MCOSMTPSession *session = [[MCOSMTPSession alloc] init];

        session.username = defaults.SMTPUsername ?: @"";
        session.hostname = defaults.SMTPServer ?: @"";
        session.port = (int)defaults.SMTPPort;

        if (defaults.SMTPTLSEnabled) {
            DLog(@"SSL/TLS is enabled for %@.", defaults.SMTPServer);
            // If the SMTP port is 465, use MCOConnectionTypeTLS.
            // Otherwise use MCOConnectionTypeStartTLS.
            if (session.port == 465) {
                session.connectionType = MCOConnectionTypeTLS;
            } else {
                session.connectionType = MCOConnectionTypeStartTLS;
            }
        } else {
            DLog(@"SSL/TLS is _not_ enabled for %@.", defaults.SMTPServer);
            session.connectionType = MCOConnectionTypeClear;
        }

        // Retrieve the SMTP password from the default keychain if it exists
        // Only check for a password if username exists
        if (defaults.SMTPAuthenticationEnabled && session.username.length) {
            [LGPasswords getPasswordForAccount:session.username reply:^(NSString *password, NSError *error) {
                if (error) {
                    if ([error code] == errSecItemNotFound) {
                        NSLog(@"Keychain item not found for account %@.", session.username);
                    } else if ([error code] == errSecNotAvailable) {
                        NSLog(@"Found the keychain item for %@ but no password value was returned.", session.username);
                    } else if (error != nil) {
                        NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", session.username, [error localizedDescription]);
                    }
                    [self didCompleteEmailOperation:error];
                } else {
                    DLog(@"Retrieved password from keychain for account %@.", session.username);
                    session.password = password ?: @"";
                    [self beginSession:session builder:builder];
                }
            }];
        } else {
            // Authentication is turned off.
            [self beginSession:session builder:builder];
        }

    } else {
        // Send email when new version found is set to false.
        [self didCompleteEmailOperation:nil];
    }
}

- (void)beginSession:(MCOSMTPSession *)smtpSession builder:(MCOMessageBuilder *)builder {

    MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:[builder data]];

    [sendOperation start:^(NSError *error) {

        NSPredicate *subjectPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[CD] 'Test notification from AutoPkgr'"];

        if ([subjectPredicate evaluateWithObject:builder.header.subject]) {
            [LGUserNotifications sendNotificationOfTestEmailSuccess:error ? NO:YES error:error];
        }

        // Call did complete operation.
        [self didCompleteEmailOperation:error];
    }];
}

- (void)sendTestEmail
{
    // Send a test email notification when the user
    // clicks "Send Test Email"
    NSString *subject = @"Test notification from AutoPkgr";
    NSString *message = @"This is a test notification from <strong>AutoPkgr</strong>.";
    // Send the email
    [self sendEmailNotification:subject message:message];
}

- (void)sendEmailForReport:(NSDictionary *)report error:(NSError *)error
{
    LGAutoPkgReport *a_report = [[LGAutoPkgReport alloc] initWithReportDictionary:report];
    a_report.error = error;
    a_report.tools = [[LGToolManager new] installedTools];

    if (a_report.updatesToReport) {
        [self sendEmailNotification:a_report.emailSubjectString message:a_report.emailMessageString];
    } else {
        [self didCompleteEmailOperation:nil];
    }
}

- (void)didCompleteEmailOperation:(NSError *)error {
    self.complete = YES;
    if (_replyBlock) {
        _replyBlock(error);
    }
}
@end
