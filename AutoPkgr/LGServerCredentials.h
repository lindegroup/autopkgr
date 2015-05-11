// LGServerCredentials.h
//
// Copyright 2015 The Linde Group, Inc.
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

#import <Foundation/Foundation.h>


typedef NS_ENUM(OSStatus, LGCredentialChallengeCode) {
    kLGCredentialChallengeFailed = 0,
    kLGCredentialChallengeSuccess = 1 << 0,
    kLGCredentialsNotChallenged = 1 << 1,
};

@interface LGServerCredentials : NSObject

- (instancetype)initWithServer:(NSString *)server
                          user:(NSString *)user
                      password:(NSString *)password;

- (void)save;

/**
 * Block that is invoked each time `-save` is called
 * @note the return value is a weak reference to `self`
 * This block can only be set once
 */
@property (copy, nonatomic) void (^saveBlock)(id credential);

@property (copy, nonatomic) NSString *user;
@property (copy, nonatomic) NSString *password;
@property (copy, nonatomic) NSString *server;

@property (copy, nonatomic, readonly) NSURL *serverURL;
@property (copy, nonatomic, readonly) NSString *protocol;
@property (copy, nonatomic, readonly) NSString *host;
@property (nonatomic, readonly) NSInteger port;



@end

#pragma mark - HTTP Server Credential
@interface LGHTTPCredential : LGServerCredentials
@property (copy, nonatomic, readonly) NSURLCredential *credential;
@property (assign, nonatomic) BOOL verifySSL;

- (void)handleCertificateTrustChallenge:(NSURLAuthenticationChallenge *)challenge reply:(void (^)(BOOL verifySSL))reply;

- (void)checkCredentialsAtPath:(NSString *)path reply:(void (^)(LGHTTPCredential * aCredential, LGCredentialChallengeCode code, NSError *error))reply;
@end

#pragma mark - NetFS Server Credential
@interface LGNetMountCredential : LGServerCredentials
- (void)checkCredentialsForShare:(NSString *)share reply:(void (^)(LGNetMountCredential *aCredential, LGCredentialChallengeCode code, NSError *error))reply;
@end
