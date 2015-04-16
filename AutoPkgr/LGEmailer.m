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
#import "LGRecipes.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGPasswords.h"
#import "LGTools.h"
#import "LGUserNotifications.h"
#import "LGAutoPkgReport.h"

@implementation LGEmailer

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message
{
    LGDefaults *defaults = [[LGDefaults alloc] init];

    if (defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled) {

        MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
        smtpSession.username = defaults.SMTPUsername ?: @"";
        smtpSession.hostname = defaults.SMTPServer ?: @"";
        smtpSession.port = (int)defaults.SMTPPort;

        if (defaults.SMTPTLSEnabled) {
            DLog(@"SSL/TLS is enabled for %@.", defaults.SMTPServer);
            // If the SMTP port is 465, use MCOConnectionTypeTLS.
            // Otherwise use MCOConnectionTypeStartTLS.
            if (smtpSession.port == 465) {
                smtpSession.connectionType = MCOConnectionTypeTLS;
            } else {
                smtpSession.connectionType = MCOConnectionTypeStartTLS;
            }
        } else {
            DLog(@"SSL/TLS is _not_ enabled for %@.", defaults.SMTPServer);
            smtpSession.connectionType = MCOConnectionTypeClear;
        }

        // Retrieve the SMTP password from the default
        // keychain if it exists
        // Only check for a password if username exists
        if (defaults.SMTPAuthenticationEnabled && ![smtpSession.username isEqualToString:@""]) {
            __block BOOL complete = NO;
            [LGPasswords getPasswordForAccount:smtpSession.username reply:^(NSString *password, NSError *error) {
                if ([error code] == errSecItemNotFound) {
                    NSLog(@"Keychain item not found for account %@.", smtpSession.username);
                } else if ([error code] == errSecNotAvailable) {
                    NSLog(@"Found the keychain item for %@ but no password value was returned.", smtpSession.username);
                } else if (error != nil) {
                    NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", smtpSession.username, [error localizedDescription]);
                } else {
                    DLog(@"Retrieved password from keychain for account %@.", smtpSession.username);
                    smtpSession.password = password ?: @"";
                }
                complete = YES;
            }];

            while (!complete) {
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
            }
        }

        NSString *from = defaults.SMTPFrom ?: @"AutoPkgr";

        MCOMessageBuilder *builder = [[MCOMessageBuilder alloc] init];
        [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"AutoPkgr Notification"
                                                             mailbox:from]];

        NSMutableArray *to = [[NSMutableArray alloc] init];
        for (NSString *toAddress in defaults.SMTPTo) {
            if (![toAddress isEqual:@""]) {
                MCOAddress *newAddress = [MCOAddress addressWithMailbox:toAddress];
                [to addObject:newAddress];
            }
        }

        NSString *fullSubject = [NSString stringWithFormat:@"%@ on %@", subject, [[NSHost currentHost] localizedName]];

        [[builder header] setTo:to];
        [[builder header] setSubject:fullSubject];
        [builder setHTMLBody:message];
        NSData *rfc822Data = [builder data];

        MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:rfc822Data];
        [sendOperation start:^(NSError *error) {

            if ([subject isEqualToString:@"Test notification from AutoPkgr"]) {
                [LGUserNotifications sendNotificationOfTestEmailSuccess:error ? NO:YES error:error];
            }
            
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{kLGNotificationUserInfoSubject:subject,
                                                                                            kLGNotificationUserInfoMessage:message}];
            
            if (error) {
                NSLog(@"Error sending email from %@: %@", from, error);
                [userInfo setObject:error forKey:kLGNotificationUserInfoError];
            } else {
                NSLog(@"Successfully sent email from %@.", from);
            }

            [center postNotificationName:kLGNotificationEmailSent
                                  object:self
                                userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
            self.complete = YES;
        }];
    } else {
        self.complete = YES;
    }
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

    LGToolStatus *toolStatus = [LGToolStatus new];
    [toolStatus allToolsStatus:^(NSArray *tools) {

        LGAutoPkgReport *a_report = [[LGAutoPkgReport alloc] initWithReportDictionary:report];
        a_report.error = error;
        a_report.tools = tools;

        if (a_report.updatesToReport) {
            [self sendEmailNotification:a_report.emailSubjectString message:a_report.emailMessageString];
        } else {
            self.complete = YES;
        }
    }];
}

@end
