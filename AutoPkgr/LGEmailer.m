//
//  LGEmailer.m
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

#import "LGEmailer.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "SSKeychain.h"

@implementation LGEmailer

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message
{
    LGDefaults *defaults = [[LGDefaults alloc] init];

    if (defaults.sendEmailNotificationsWhenNewVersionsAreFoundEnabled) {
        BOOL TLS = defaults.SMTPTLSEnabled;

        MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
        smtpSession.username = defaults.SMTPUsername ? defaults.SMTPUsername : @"";
        smtpSession.hostname = defaults.SMTPServer ? defaults.SMTPServer : @"";
        smtpSession.port = (int)defaults.SMTPPort;

        if (TLS) {
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
        NSError *error = nil;

        if (smtpSession.username) {
            NSString *password = [SSKeychain passwordForService:kLGApplicationName
                                                        account:smtpSession.username
                                                          error:&error];

            if ([error code] == errSecItemNotFound) {
                NSLog(@"Keychain item not found for account %@.", smtpSession.username);
            } else if ([error code] == errSecNotAvailable) {
                NSLog(@"Found the keychain item for %@ but no password value was returned.", smtpSession.username);
            } else if (error != nil) {
                NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", smtpSession.username, [error localizedDescription]);
            } else {
                // Only set the SMTP session password if the username exists
                if (smtpSession.username != nil && ![smtpSession.username isEqual:@""]) {
                    DLog(@"Retrieved password from keychain for account %@.", smtpSession.username);
                    smtpSession.password = password ? password : @"";
                }
            }
        }

        NSString *from = defaults.SMTPFrom ? defaults.SMTPFrom : @"AutoPkgr";

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
        }];
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
    // Get arrays of new downloads/packages from the plist
    NSMutableString *message;
    NSString *subject;
    NSArray *newDownloads;
    NSArray *newPackages;
    NSArray *newImports;

    if (report) {
        newDownloads = [report objectForKey:@"new_downloads"];
        newPackages = [report objectForKey:@"new_packages"];
        newImports = [report objectForKey:@"new_imports"];
    }

    if ([newDownloads count]) {
        message = [[NSMutableString alloc] init];
        NSLog(@"New stuff was downloaded.");

        // Create the subject string
        subject = [NSString stringWithFormat:@"[%@] New software available for testing", kLGApplicationName];

        // Append the the message string with report
        [message appendFormat:@"The following software is now available for testing:<br />"];

        for (NSString *path in newDownloads) {
            NSCharacterSet *set = [NSCharacterSet punctuationCharacterSet];

            // Get just the application name from the path in the new_downloads dict
            NSString *downloadFile = [path lastPathComponent];
            NSString *app = [[downloadFile componentsSeparatedByCharactersInSet:set] firstObject];

            // Write the app to the string
            [message appendFormat:@"<strong>%@</strong>: ", app];

            // The default version is not detected, override later.
            NSString *version;

            NSPredicate *versionPredicate = [NSPredicate predicateWithFormat:@" %K CONTAINS[cd] %@", @"pkg_path", app];

            for (NSDictionary *dict in newPackages) {
                if ([versionPredicate evaluateWithObject:dict] && dict[@"version"]) {
                    version = dict[@"version"];
                    break;
                }
            }

            if (!version) {
                for (NSDictionary *dict in newImports) {
                    if ([versionPredicate evaluateWithObject:dict] && dict[@"version"]) {
                        version = dict[@"version"];
                        break;
                    }
                }
            }

            [message appendFormat:@"%@<br/>", version ? version : @"Version not detected"];
        }
    } else {
        DLog(@"Nothing new was downloaded.");
    }

    if (error) {
        if (!message) {
            message = [[NSMutableString alloc] init];
        } else {
            [message appendString:@"<br/>"];
        }

        if (!subject) {
            subject = [NSString stringWithFormat:@"[%@] Error occured while running AutoPkg", kLGApplicationName];
        }
        [message appendFormat:@"<strong>The following error occured:</strong><br /><br />%@<br />%@", error.localizedDescription, error.localizedRecoverySuggestion];
    }

    if (message) {
        [self sendEmailNotification:subject message:message];
    }
}

@end
