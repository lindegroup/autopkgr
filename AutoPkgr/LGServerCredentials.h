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

/**
 *  LGCredentialChallengeCode, Chalenge results.
 */
typedef NS_ENUM(OSStatus, LGCredentialChallengeCode) {
    /**
     *  The Credentials provided were incorrect
     */
    kLGCredentialChallengeFailed = 0,
    /**
     *  The Credentials provided were correct
     */
    kLGCredentialChallengeSuccess = 1 << 0,

    /**
     *  The credentials were never tested.
     *  @note most likely the path specified did not require authentication.
     */
    kLGCredentialsNotChallenged = 1 << 1,
};

/**
 *  LGSSLTrustSettings, trust level of server ssl certificates.
 */
typedef NS_ENUM(OSStatus, LGSSLTrustSettings) {

    // The trust setting is unknown
    kLGSSLTrustStatusUnknown = 0,

    // Do not trust the SSL.
    kLGSSLTrustUntrusted = 1 << 0,

    // The user confirmed trust as a result of a trust panel interaction.
    kLGSSLTrustUserConfirmedTrust = 1 << 1,

    // The user has explicitly told the OS to trust the certificate (set in Keychain)
    kLGSSLTrustUserExplicitTrust = 1 << 2,

    // The OS implicitly trusts this certificate. It is globaly valid.
    kLGSSLTrustOSImplicitTrust = 1 << 3,
};

@interface LGServerCredentials : NSObject

- (instancetype)initWithServer:(NSString *)server
                          user:(NSString *)user
                      password:(NSString *)password;

/**
 *  Save the current credentials.
 *  @note calling save invokes the saveBlock, it is up to you define how the credentials are stored into persistence.
 */
- (void)save;

/**
 *The block to be executed  when `-save` is called. This block has no return value and takes one arguments: the receiver credential. This block can only be set once
 */
@property (copy, nonatomic) void (^saveBlock)(id aCredential);

/**
 *  Username used for authentication.
 */
@property (copy, nonatomic) NSString *user;

/**
 *  Password used for authentication
 */
@property (copy, nonatomic) NSString *password;

/**
 *  Server address used for authentication
 *  @note This should be a fully formed url string including protocol and port.
 */
@property (copy, nonatomic) NSString *server;

/**
 *  The server property converted into an NSURL
 */
@property (copy, nonatomic, readonly) NSURL *serverURL;

/**
 *  The protocol of the server.
 *  @note The `server` property must first be set.
 */
@property (copy, nonatomic, readonly) NSString *protocol;

/**
 *  The host name for the server
 *  @note The `server` property must first be set.
 */
@property (copy, nonatomic, readonly) NSString *host;

/**
 *  The port for the server
 *  @note The `server` property must first be set. If no port is explicitly defined, this will attempt to guess the port based on default ports.
 */
@property (nonatomic) NSInteger port;

@end

#pragma mark - HTTP Server Credential
/**
 *  Server credential for HTTP requests.
 */
@interface LGHTTPCredential : LGServerCredentials

/**
 *  NSURLCredential derived from the defined user and password.
 */
@property (copy, nonatomic, readonly) NSURLCredential *credential;

/**
 *  validity level of SSL certificates and certificate chains.
 */
@property (assign, nonatomic) LGSSLTrustSettings sslTrustSetting;

/**
 *  Handle a authentication challenge by presenting a dialog asking to verify an untrusted certificate
 *
 *  @param challenge challenge from the request
 *  @param reply reply block that takes one parameter, verifySSL, to indicate the result of the challenge.
 */
- (void)handleCertificateTrustChallenge:(NSURLAuthenticationChallenge *)challenge reply:(void (^)(LGSSLTrustSettings trust))reply;

/**
 *  Check the credentials for a specified path
 *
 *  @param path  URL path to test credentials for.
 *  @param reply reply block that takes three parameters, the original credential, the response code, and an error if one should occur.
 */
- (void)checkCredentialsForPath:(NSString *)path reply:(void (^)(LGHTTPCredential *aCredential, LGCredentialChallengeCode code, NSError *error))reply;
@end

#pragma mark - NetFS Server Credential
/**
 *  Server credentials for network shares.
 */
@interface LGNetMountCredential : LGServerCredentials
/**
 *  Check the credentials for a specified share
 *
 *  @param share  Server share point to test credentials for.
 *  @param reply reply block that takes three parameters, the original credential, the response code, and an error if one should occur.
 */
- (void)checkCredentialsForShare:(NSString *)share reply:(void (^)(LGNetMountCredential *aCredential, LGCredentialChallengeCode code, NSError *error))reply;
@end
