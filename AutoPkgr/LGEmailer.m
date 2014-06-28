//
//  LGEmailer.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGEmailer.h"
#import "LGConstants.h"
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
        smtpSession.connectionType = MCOConnectionTypeTLS;
    } else {
        NSLog(@"SSL/TLS is _not_ enabled for %@.", [defaults objectForKey:kSMTPServer]);
        smtpSession.connectionType = MCOConnectionTypeClear;
    }

    // Retrieve the SMTP password from the default keychain
    NSError *error = nil;
    NSString *password = [SSKeychain passwordForService:kApplicationName
                                                account:[[NSUserDefaults standardUserDefaults] objectForKey:kSMTPUsername]
                                                  error:&error];

    if ([error code] == SSKeychainErrorNotFound) {
        NSLog(@"Unable to retrieve password for account %@.", smtpSession.username);
    } else {
        smtpSession.password = password;
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
        if (error) {
            NSLog(@"%@ Error sending email:%@", smtpSession.username, error);
        } else {
            NSLog(@"%@ Successfully sent email!", smtpSession.username);
        }
    }];
}

- (void)sendTestEmail
{
    // Send a test email notification when the user
    // clicks "Send Test Email"
    NSString *subject = @"Test notification from AutoPkgr";
    NSString *message = @"<html><body><div><p>This is a test notification from <strong>AutoPkgr</strong>.</p></div></body></html>";
    // Send the email
    [self sendEmailNotification:subject message:message];
    
}

@end
