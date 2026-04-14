//
//  LGEmailNotification.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGAutoPkgr.h"
#import "LGEmailNotification.h"
#import "LGPasswords.h"
#import "LGServerCredentials.h"
#import "LGUserNotification.h"

#include <curl/curl.h>

#pragma mark - libcurl read callback

// Context for feeding message data to libcurl's SMTP upload.
typedef struct {
    const char *data;
    size_t length;
    size_t offset;
} LGCurlUploadContext;

static size_t lgCurlReadCallback(char *buffer, size_t size, size_t nitems, void *userdata)
{
    LGCurlUploadContext *ctx = (LGCurlUploadContext *)userdata;
    size_t remaining = ctx->length - ctx->offset;
    size_t bufferSize = size * nitems;
    size_t toCopy = (remaining < bufferSize) ? remaining : bufferSize;
    if (toCopy == 0) return 0;
    memcpy(buffer, ctx->data + ctx->offset, toCopy);
    ctx->offset += toCopy;
    return toCopy;
}

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

+ (BOOL)templateIsFile
{
    return YES;
}

+ (NSString *)defaultTemplate
{
    return [self templateWithName:@"report" type:@"html"];
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

    NSString *subject = self.report.reportSubject;
    NSString *message = [self.report renderWithTemplate:[[self class] reportTemplate] error:nil];

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

    // Send the email.
    [self sendEmailNotification:subject message:message test:YES];
}

- (void)sendMessage:(NSString *)message title:(NSString *)title complete:(void (^)(NSError *))complete
{
    if (complete && !self.notificatonComplete) {
        self.notificatonComplete = complete;
    }
    [self sendEmailNotification:title message:message test:YES];
}

#pragma mark - Credentials
- (void)getMailCredentials:(void (^)(LGHTTPCredential *, NSError *))reply
{
    /* This sends back a credential object with three properties:
     * 1) Server Name
     * 2) User Name, if authentication is enabled
     * 3) Password, if authentication is enabled */
    LGHTTPCredential *credential = [[LGHTTPCredential alloc] init];

    credential.server = _defaults.SMTPServer;
    credential.port = _defaults.SMTPPort;

    if (!credential.server || !credential.port) {
        return reply(nil, [LGError errorWithCode:kLGErrorSendingEmail]);
    }

    if (_defaults.SMTPAuthenticationEnabled) {
        [[self class] infoFromKeychain:^(NSString *infoOrPassword, NSError *error) {
            credential.user = [[self class] account];
            credential.password = infoOrPassword ?: @"";
            DLog(@"SMTP credentials retrieved.");
            reply(credential, error);
        }];
    }
    else {
        DLog(@"Not using SMTP authentication.");
        reply(credential, nil);
    }
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
            NSLog(@"There was a problem getting the SMTP credentials: %@", error);
            return didCompleteSendOperation(error);
        }

        // Collect valid recipient addresses.
        NSMutableArray *toAddresses = [NSMutableArray array];
        for (NSString *addr in _defaults.SMTPTo) {
            if (addr.length) [toAddresses addObject:addr];
        }

        // Build the raw RFC 2822 message.
        NSString *fromAddress = _defaults.SMTPFrom ?: @"autopkgr@localhost";
        NSMutableString *rawMessage = [NSMutableString string];
        [rawMessage appendFormat:@"From: AutoPkgr Notification <%@>\r\n", fromAddress];
        for (NSString *addr in toAddresses) {
            [rawMessage appendFormat:@"To: %@\r\n", addr];
        }
        [rawMessage appendFormat:@"Subject: %@\r\n", subject];
        [rawMessage appendString:@"MIME-Version: 1.0\r\n"];
        [rawMessage appendString:@"Content-Type: text/html; charset=UTF-8\r\n"];
        [rawMessage appendString:@"\r\n"];
        [rawMessage appendString:message];

        NSData *messageData = [rawMessage dataUsingEncoding:NSUTF8StringEncoding];
        BOOL tlsEnabled = _defaults.SMTPTLSEnabled;

        // Run the libcurl SMTP transfer on a background queue.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *sendError = [self sendViaCurl:messageData
                                       fromAddress:fromAddress
                                       toAddresses:toAddresses
                                        credential:credential
                                        tlsEnabled:tlsEnabled];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (test) {
                    [LGUserNotification sendNotificationOfTestEmailSuccess:sendError ? NO : YES error:sendError];
                }
                didCompleteSendOperation(sendError);
            });
        });
    }];
}

#pragma mark - libcurl SMTP
- (NSError *)sendViaCurl:(NSData *)messageData
             fromAddress:(NSString *)from
             toAddresses:(NSArray<NSString *> *)toAddresses
              credential:(LGHTTPCredential *)credential
              tlsEnabled:(BOOL)tlsEnabled
{
    CURL *curl = curl_easy_init();
    if (!curl) {
        return [NSError errorWithDomain:kLGApplicationName
                                   code:kLGErrorSendingEmail
                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to initialize libcurl"}];
    }

    // Build the server URL: smtps:// for implicit TLS (port 465), smtp:// otherwise.
    NSString *scheme = (tlsEnabled && credential.port == 465) ? @"smtps" : @"smtp";
    NSString *url = [NSString stringWithFormat:@"%@://%@:%ld", scheme, credential.server, (long)credential.port];
    curl_easy_setopt(curl, CURLOPT_URL, url.UTF8String);

    // Require STARTTLS when TLS is enabled but not using implicit TLS.
    if (tlsEnabled && credential.port != 465) {
        curl_easy_setopt(curl, CURLOPT_USE_SSL, (long)CURLUSESSL_ALL);
    }

    // Authentication (credentials stay in-process, never visible in ps).
    if (credential.user.length && credential.password.length) {
        curl_easy_setopt(curl, CURLOPT_USERNAME, credential.user.UTF8String);
        curl_easy_setopt(curl, CURLOPT_PASSWORD, credential.password.UTF8String);
    }

    // Envelope sender and recipients.
    curl_easy_setopt(curl, CURLOPT_MAIL_FROM, from.UTF8String);
    struct curl_slist *recipients = NULL;
    for (NSString *addr in toAddresses) {
        recipients = curl_slist_append(recipients, addr.UTF8String);
    }
    curl_easy_setopt(curl, CURLOPT_MAIL_RCPT, recipients);

    // Provide the message body via read callback (no temp file needed).
    LGCurlUploadContext ctx = {
        .data = messageData.bytes,
        .length = messageData.length,
        .offset = 0,
    };
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, lgCurlReadCallback);
    curl_easy_setopt(curl, CURLOPT_READDATA, &ctx);
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);

    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);

    CURLcode res = curl_easy_perform(curl);
    curl_slist_free_all(recipients);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        NSString *detail = [NSString stringWithFormat:@"SMTP send failed: %s", curl_easy_strerror(res)];
        return [NSError errorWithDomain:kLGApplicationName
                                   code:kLGErrorSendingEmail
                               userInfo:@{NSLocalizedDescriptionKey: detail}];
    }
    return nil;
}

@end
