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
#import "LGRecipes.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "AHKeychain.h"
#import "LGUserNotifications.h"

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
        NSError *error = nil;

        // Only check for a password if username exists
        if (defaults.SMTPAuthenticationEnabled && ![smtpSession.username isEqualToString:@""]) {
            AHKeychain *keychain = [LGHostInfo appKeychain];
            AHKeychainItem *item = [[AHKeychainItem alloc] init];

            item.label = kLGApplicationName;
            item.service = kLGAutoPkgrPreferenceDomain;
            item.account = smtpSession.username;

            [keychain getItem:item error:&error];
            NSString *password = item.password;

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
    // Get arrays of new downloads/packages from the plist
    NSMutableString *message;
    NSString *subject;
    NSArray *newDownloads;
    NSArray *newPackages;
    NSArray *newImports;
    NSArray *detectedVersions;

    if (report) {
        detectedVersions = [report objectForKey:@"detected_versions"] ?: @[];
        newDownloads = [report objectForKey:@"new_downloads"] ?: @[];
        newPackages = [report objectForKey:@"new_packages"] ?: @[];
        newImports = [report objectForKey:@"new_imports"] ?: @[];
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

            BOOL version_found = NO;
            for (NSArray *arr in @[ newPackages, newImports, detectedVersions ]) {
                for (NSDictionary *dict in arr) {
                    if ([versionPredicate evaluateWithObject:dict] && dict[@"version"]) {
                        version = dict[@"version"];
                        version_found = YES;
                        break;
                    }
                }
                if (version_found) {
                    break;
                }
            }

            [message appendFormat:@"%@<br/>", version ?: @"Version not detected"];
        }
    } else {
        DLog(@"Nothing new was downloaded.");
    }

    // Process error
    if (error) {
        if (!message) {
            message = [[NSMutableString alloc] init];
        } else {
            [message appendString:@"<br/>"];
        }

        // Set up a few CSS styles
        [message appendString:@"<style>.tabbed {margin-left: 1em;} .tabbed2 {margin-left: 2em;}</style>"];

        if (!subject) {
            subject = [NSString stringWithFormat:@"[%@] Error occurred while running AutoPkg", kLGApplicationName];
        }

        NSArray *recoverySuggestions = [error.localizedRecoverySuggestion
            componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        [message appendFormat:@"<strong>The following error%@ occurred:</strong><br/>", recoverySuggestions.count > 1 ? @"s" : @""];

        NSString *noValidRecipe = @"No valid recipe found for ";
        NSPredicate *noValidRecipePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", noValidRecipe];

        for (NSString *string in [recoverySuggestions removeEmptyStrings]) {
            if ([noValidRecipePredicate evaluateWithObject:string]) {
                // Remove Recipe from Recipe.txt

                [LGRecipes removeRecipeFromRecipeList:[[string componentsSeparatedByString:noValidRecipe] lastObject]];
                [message appendFormat:@"<p class =\"tabbed\">%@. It has been automatically removed from your recipe list in order to prevent recurring errors.</p>", string];
            } else {
                [message appendFormat:@"<p class =\"tabbed\">%@</p>", string];
            }
        }
    }

    if (message) {
        [self sendEmailNotification:subject message:message];
    } else {
        self.complete = YES;
    }
}

@end
