//
//  LGPasswords.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 2/14/15.
//  Copyright 2015-2016 The Linde Group, Inc.
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

extern NSString *appKeychainPath();

@interface LGPasswords : NSObject

+ (void)lockKeychain;

+ (void)getPasswordForAccount:(NSString *)account
                        reply:(void (^)(NSString *password, NSError *error))reply __deprecated_msg("use getPasswordForAccount:service:label:reply instead.");

+ (void)getPasswordForAccount:(NSString *)account
                      service:(NSString *)service
                        label:(NSString *)label
                        reply:(void (^)(NSString *password, NSError *error))reply;

+ (void)savePassword:(NSString *)password
          forAccount:(NSString *)account
               reply:(void (^)(NSError *error))reply __deprecated_msg("use savePassword:forAccount:service:label:reply instead.");

+ (void)savePassword:(NSString *)password
          forAccount:(NSString *)account
             service:(NSString *)service
               label:(NSString *)label
               reply:(void (^)(NSError *error))reply;

+ (void)migrateKeychainIfNeeded:(void (^)(NSString *password, NSError *error))reply;

+ (void)resetKeychainPrompt:(void (^)(NSError *))reply;
@end
