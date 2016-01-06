//
//  LGNotificationService.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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

#import <Foundation/Foundation.h>

#import "LGAutoPkgReport.h"
#import <ACEModes.h>

/**
 *  Base protocol for LGNotification service.
 */
@protocol LGNotificationServiceProtocol <NSObject>
@required
// A short description of what the service is. Is included in error message. Must implement in subclass
+ (NSString *)serviceDescription;

// Should the notification report integrations?
+ (BOOL)reportsIntegrations;

// Is the service enabled? (most likely a lookup against NSUserDefaults)
+ (BOOL)isEnabled;

// Is the report template a file. return YES if a file, NO if it's a string
+ (BOOL)templateIsFile;

// Default notification template. 
+ (NSString *)defaultTemplate;

// Send the notification.
- (void)send:(void (^)(NSError *))complete;

// Send a test notification.
- (void)sendTest:(void (^)(NSError *))complete;

// Send a message.
- (void)sendMessage:(NSString *)message title:(NSString *)title complete:(void (^)(NSError *))complete;

@optional
/**
 *  @return Link to the home page of the service.
 */
+ (NSURL *)serviceURL;

// Whether the class stores information in the a keychain item. Defaults to NO;
+ (BOOL)storesInfoInKeychain;

// If store in keychain is enabled, this needs to be overriden in subclass, (either a lookup against NSUserDefaults, or a constant string if the value will never change.)
+ (NSString *)account;

/* (Optional) used to specify a unique service description for the keychain item, defaults to +serviceDescription
 * @note this is mostly used when there's a possible service name clash with a previous keychain item.
 */
+ (NSString *)keychainServiceDescription;

/* (Optional) used to specify a unique lable for the keychain item, defaults to +serviceDescription
 * @note this is mostly used when there's a possible label name clash with a previous keychain item.
 */
+ (NSString *)keychainServiceLabel;

// Mustache template that report data is applied to
+ (NSString *)reportTemplate;

+ (ACEMode)tempateFormat;

+ (void)setReportTemplate:(NSString *)reportTemplate;
@end

@interface LGNotificationService : NSObject

// This will pull info from the keychain if +keychainServiceName. +storesInfoInKeychain must be set to YES, and +account must be defined in subclass;
+ (void)infoFromKeychain:(void (^)(NSString *infoOrPassword, NSError *error))reply;

// This will pull info from the keychain if +keychainServiceName. +storesInfoInKeychain must be set to YES, and +account must be defined in subclass;
+ (void)saveInfoToKeychain:(NSString *)info reply:(void (^)(NSError *error))reply;

// Get a template by name from the main bundle.
+ (NSString *)templateWithName:(NSString *)name type:(NSString *)type;

- (instancetype)initWithReport:(LGAutoPkgReport *)report;

@property (strong, nonatomic, readonly) LGAutoPkgReport *report;

// Completion block when executed on sending
@property (copy, nonatomic) void (^notificatonComplete)(NSError *error);

@end
