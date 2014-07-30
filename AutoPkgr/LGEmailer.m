//
//  LGEmailer.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGEmailer.h"
#import "LGHostInfo.h"
#import "SSKeychain.h"

@implementation LGEmailer

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    BOOL TLS = [[defaults objectForKey:kSMTPTLSEnabled] boolValue];

    MCOSMTPSession *smtpSession = [[MCOSMTPSession alloc] init];
    smtpSession.hostname = [defaults objectForKey:kSMTPServer];
    smtpSession.port = (int)[defaults integerForKey:kSMTPPort];
    smtpSession.username = [defaults objectForKey:kSMTPUsername];

    if (TLS) {
        NSLog(@"SSL/TLS is enabled for %@.", [defaults objectForKey:kSMTPServer]);
        // If the SMTP port is 465, use MCOConnectionTypeTLS.
        // Otherwise use MCOConnectionTypeStartTLS.
        if (smtpSession.port == 465) {
            smtpSession.connectionType = MCOConnectionTypeTLS;
        } else {
            smtpSession.connectionType = MCOConnectionTypeStartTLS;
        }
    } else {
        NSLog(@"SSL/TLS is _not_ enabled for %@.", [defaults objectForKey:kSMTPServer]);
        smtpSession.connectionType = MCOConnectionTypeClear;
    }

    // Retrieve the SMTP password from the default
    // keychain if it exists
    NSError *error = nil;
    NSString *smtpUsernameString = [defaults objectForKey:kSMTPUsername];

    if (smtpUsernameString) {
        NSString *password = [SSKeychain passwordForService:kApplicationName
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
                                                                  objectForKey:kSMTPFrom]]];

    NSMutableArray *to = [[NSMutableArray alloc] init];
    for (NSString *toAddress in [[NSUserDefaults standardUserDefaults] objectForKey:kSMTPTo]) {
        if (![toAddress isEqual:@""]) {
            MCOAddress *newAddress = [MCOAddress addressWithMailbox:toAddress];
            [to addObject:newAddress];
        }
    }

    [[builder header] setTo:to];
    [[builder header] setSubject:subject];
    [builder setHTMLBody:message];
    NSData * rfc822Data = [builder data];

    MCOSMTPSendOperation *sendOperation = [smtpSession sendOperationWithData:rfc822Data];
    [sendOperation start:^(NSError *error) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjects:[NSArray arrayWithObjects:subject, message, nil]
                                                      forKeys:[NSArray arrayWithObjects:kEmailSentNotificationSubject, kEmailSentNotificationMessage, nil]];
        
        if (error) {
            NSLog(@"%@ Error sending email:%@", smtpSession.username, error);
            [d setObject:error forKey:kEmailSentNotificationError];
        } else {
            NSLog(@"%@ Successfully sent email!", smtpSession.username);
        }
        
        [center postNotificationName:kEmailSentNotification
                              object:self
                            userInfo:[NSDictionary dictionaryWithDictionary:d]];
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

@end
