//
//  LGNotificationManager.m
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

#import "LGNotificationManager.h"
#import "LGNotificationService.h"
#import "LGUserNotification.h"
#import "LGEmailNotification.h"
#import "LGSlackNotification.h"
#import "LGHipChatNotification.h"

#import "LGPasswords.h"
#import "LGIntegrationManager.h"

#import "NSArray+mapped.h"

@interface LGNotificationService ()<LGNotificationServiceProtocol>
@end

const NSArray *NotificationServiceClasses()
{
    static dispatch_once_t onceToken;
    __strong static NSArray *classes = nil;
    dispatch_once(&onceToken, ^{
        classes =  @[ [LGEmailNotification class],
                      [LGSlackNotification class],
                      [LGHipChatNotification class],
                      [LGUserNotification class]
                      ];
    });
    return classes;
}

@implementation LGNotificationManager {
    NSMutableArray *_reportedErrors;
    NSError *_runError;
}

- (instancetype)initWithReportDictionary:(NSDictionary *)dictionary errors:(NSError *)error
{
    if (self = [super init]) {
        _reportDictionary = dictionary;
        _runError = error;
    }
    return self;
}

- (void)sendEnabledNotifications:(void (^)(NSError *))complete;
{

    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [queue addOperationWithBlock:^{

        __block BOOL reportsIntegrations = NO;
        LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:self.reportDictionary];
        report.error = _runError;

        NSArray *enabledServices = [NotificationServiceClasses() mapObjectsUsingBlock:^id(Class noteClass, NSUInteger idx) {
            LGNotificationService *service = nil;
            if ([noteClass isEnabled]) {
                service = [[noteClass alloc] initWithReport:report];
                if ([[service class] reportsIntegrations]) {
                    reportsIntegrations = YES;
                }
            }
            return service;
        }];

        NSInteger expectedServices = enabledServices.count;
        __block NSInteger completedCounter = 0;

        /* If no services are enabled, send the
         * completion message now and return */
        if (expectedServices == 0) {
            return complete(nil);
        }

        /* If any enabled service report integrations grab them now. */
        if (reportsIntegrations) {
            LGIntegrationManager *manager = [[LGIntegrationManager alloc] init];
            report.integrations = manager.allIntegrations;
        }

        /* Now that the integrations are set if needed,
         * check the report for anything new to report
         * and return  if the answer is NO. */
        if (report.updatesToReport == NO) {
            return complete(nil);
        }

        /* Set up a completion callback block to keep track
         * of the number of enabled services vs. the number
         * of services that are done sending a message. Once
         * everything has checked back in from their send
         * operation call our `complete()` block. */
        void (^completedService)() = ^(){
            completedCounter ++;
            if (completedCounter >= expectedServices) {
                NSError *error = [self processedError];

                /* We're all done sending notifications
                 * so go ahead and re-lock the keychain */
                dispatch_async(dispatch_get_main_queue(), ^{
                    complete(error);
                    [LGPasswords lockKeychain];
                });
            }
        };

        for (LGNotificationService *service in enabledServices) {
            [service send:^(NSError *error) {
                if (error) {
                    if (!_reportedErrors) {
                        _reportedErrors = [NSMutableArray arrayWithCapacity:enabledServices.count];
                    }
                    [_reportedErrors addObject:@{[[service class] serviceDescription] : error}];
                }
                completedService();
            }];
        }
    }];
}

- (NSError *)processedError
{
    NSError *error = nil;
    if (_reportedErrors.count) {
        NSMutableString *errorDescription = [[NSMutableString alloc] init];
        __block NSInteger code = 0;

        [_reportedErrors enumerateObjectsUsingBlock:^(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
            [dict enumerateKeysAndObjectsUsingBlock:^(NSString * serviceName, NSError *err, BOOL *stop) {
                [errorDescription appendFormat:@"*%@: %@\n", serviceName, err.localizedRecoverySuggestion ?: err.localizedDescription ];
                code = err.code;
            }];
        }];

        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"An error occurred while sending notifications.", nil),
                                    NSLocalizedRecoverySuggestionErrorKey : errorDescription };

        error = [NSError errorWithDomain:kLGApplicationName code:1 userInfo:userInfo];
    }
    return error;
}

@end
