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
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    BOOL TLS = [[defaults objectForKey:kLGSMTPTLSEnabled] boolValue];

    MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
    smtpSession.hostname = [defaults objectForKey:kLGSMTPServer];
    smtpSession.port = (int)[defaults integerForKey:kLGSMTPPort];
    smtpSession.username = [defaults objectForKey:kLGSMTPUsername];

    if (TLS) {
        NSLog(@"SSL/TLS is enabled for %@.", [defaults objectForKey:kLGSMTPServer]);
        // If the SMTP port is 465, use MCOConnectionTypeTLS.
        // Otherwise use MCOConnectionTypeStartTLS.
        if (smtpSession.port == 465) {
            smtpSession.connectionType = MCOConnectionTypeTLS;
        } else {
            smtpSession.connectionType = MCOConnectionTypeStartTLS;
        }
    } else {
        NSLog(@"SSL/TLS is _not_ enabled for %@.", [defaults objectForKey:kLGSMTPServer]);
        smtpSession.connectionType = MCOConnectionTypeClear;
    }

    // Retrieve the SMTP password from the default
    // keychain if it exists
    NSError *error = nil;
    NSString *smtpUsernameString = [defaults objectForKey:kLGSMTPUsername];

    if (smtpUsernameString) {
        NSString *password = [SSKeychain passwordForService:kLGApplicationName
                                                    account:smtpUsernameString
                                                      error:&error];

        if ([error code] == SSKeychainErrorNotFound) {
            NSLog(@"Keychain item not found for account %@.", smtpSession.username);
        } else if([error code] == SSKeychainErrorNoPassword) {
            NSLog(@"Found the keychain item for %@ but no password value was returned.", smtpUsernameString);
        } else if (error != nil) {
            NSLog(@"An error occurred when attempting to retrieve the keychain entry for %@. Error: %@", smtpUsernameString, [error localizedDescription]);
        } else {
            // Only set the SMTP session password if the username exists
            if (smtpUsernameString != nil && ![smtpUsernameString isEqual:@""]) {
                NSLog(@"Retrieved password from keychain for account %@.", smtpUsernameString);
                smtpSession.password = password;
            }
        }
    }

    MCOMessageBuilder * builder = [[MCOMessageBuilder alloc] init];

    [[builder header] setFrom:[MCOAddress addressWithDisplayName:@"AutoPkgr Notification"
                                                         mailbox:[[NSUserDefaults standardUserDefaults]
                                                                  objectForKey:kLGSMTPFrom]]];

    NSMutableArray *to = [[NSMutableArray alloc] init];
    for (NSString *toAddress in [[NSUserDefaults standardUserDefaults] objectForKey:kLGSMTPTo]) {
        if (![toAddress isEqual:@""]) {
            MCOAddress *newAddress = [MCOAddress addressWithMailbox:toAddress];
            [to addObject:newAddress];
        }
    }
    NSString *fullSubject = [NSString stringWithFormat:@"%@ on %@",subject,[[NSHost currentHost] name]];
    [[builder header] setTo:to];
    [[builder header] setSubject:fullSubject];
    [builder setHTMLBody:message];
    NSData * rfc822Data = [builder data];

    MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:rfc822Data];
    [sendOperation start:^(NSError *error) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:@{kLGNotificationUserInfoSubject:subject,
                                                                                        kLGNotificationUserInfoMessage:message}];
        
        if (error) {
            NSLog(@"%@ Error sending email:%@", smtpSession.username, error);
            [userInfo setObject:error forKey:kLGNotificationUserInfoError];
        } else {
            NSLog(@"%@ Successfully sent email!", smtpSession.username);
        }
        
        [center postNotificationName:kLGNotificationEmailSent
                              object:self
                            userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
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
    // Get arrays of new downloads/packages from the plist
    NSMutableString *message = [[NSMutableString alloc] init];
    NSString *subject;
    NSMutableArray *newDownloadsArray;
    NSArray *newDownloads;
    NSArray *newPackages;
    
    if (report) {
        newDownloads = [report objectForKey:@"new_downloads"];
        newPackages = [report objectForKey:@"new_packages"];
    }
    
    if ([newDownloads count]) {
        NSLog(@"New stuff was downloaded.");
        newDownloadsArray = [[NSMutableArray alloc] init];
        for (NSString *path in newDownloads) {
            NSMutableDictionary *newDownloadDict = [[NSMutableDictionary alloc] init];
            // Get just the application name from the path in the new_downloads dict
            NSString *app = [[path lastPathComponent] stringByDeletingPathExtension];
            // Insert the app name into the dictionary for the "app" key
            [newDownloadDict setObject:app forKey:@"app"];
            
            for (NSDictionary *dct in newPackages) {
                NSString *pkgPath = [dct objectForKey:@"pkg_path"];
                [newDownloadDict setObject:@"Version Undetected" forKey:@"version"];

                if ([pkgPath rangeOfString:app options:NSCaseInsensitiveSearch].location != NSNotFound && [dct objectForKey:@"version"]) {
                    NSString *version = [dct objectForKey:@"version"];
                    [newDownloadDict setObject:version forKey:@"version"];
                    break;
                }
            }
            [newDownloadsArray addObject:newDownloadDict];
        }
        
        NSMutableArray *apps = [[NSMutableArray alloc] init];
        
        for (NSDictionary *download in report) {
            NSString *app = [download objectForKey:@"app"];
            [apps addObject:app];
        }
        
        // Create the subject string
        subject = [NSString stringWithFormat:@"[%@] New Software Avaliable For Testing On %@",kLGApplicationName,[NSHost currentHost]];
        
        // Create the message string
        NSMutableString *newDownloadsString = [NSMutableString string];
        NSEnumerator *e = [newDownloadsArray objectEnumerator];
        id dictionary;
        while ((dictionary = [e nextObject]) != nil)
            [newDownloadsString appendFormat:@"<br /><strong>%@</strong>: %@", [dictionary objectForKey:@"app"], [dictionary objectForKey:@"version"]];
        
        [message appendFormat:@"The following software is now available for testing:<br />%@", newDownloadsString];
        
    } else {
        DLog(@"Nothing new was downloaded.");
    }

    if (error) {
        if (!subject){
            subject = [NSString stringWithFormat:@"[%@] Error Occured While Running AutoPkg On %@",kLGApplicationName,[NSHost currentHost]];
        }
        [message appendFormat:@"The following error occured:<br />%@",error.localizedDescription];
    }
    
    [self sendEmailNotification:subject message:[NSString stringWithString:message]];
}

@end
