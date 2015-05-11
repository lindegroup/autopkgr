// LGServerCredentials.m
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

#import "LGServerCredentials.h"
#import "LGConstants.h"
#import "LGDefaults.h"
#import "LGLogger.h"

#import <SecurityInterface/SFCertificateTrustPanel.h>
#import <NetFS/NetFS.h>
#include <sys/mount.h>

#import <AFNetworking/AFNetworking.h>


@interface LGServerCredentials ()
@property (copy, nonatomic, readwrite) NSDictionary *defaultsRepresentation;
@end

@implementation LGServerCredentials

@synthesize port = _port;
@synthesize serverURL = _serverURL;

- (void)dealloc
{
    DevLog(@"Deallocating %@", [self class]);
}

- (instancetype)initWithServer:(NSString *)server user:(NSString *)user password:(NSString *)password
{
    if (self = [super init]) {
        _server = server;
        _user = user;
        _password = password;
    }
    return self;
}

- (void)save
{
    if (_saveBlock) {
        _saveBlock(self);
    }
}

- (void)setSaveBlock:(void (^)(id))saveBlock
{
    if (!_saveBlock || saveBlock == nil) {
        _saveBlock = saveBlock;
    }
}

- (NSURL *)serverURL
{
    if (!_serverURL) {
        _serverURL = [NSURL URLWithString:self.server];
    }
    return _serverURL;
}

- (NSString *)protocol
{
    return self.serverURL.scheme;
}

- (NSInteger)port
{
    return self.serverURL.port.integerValue;
}

#pragma mark - Error Helper
- (NSError *)errorWithMessage:(NSString *)message code:(NSInteger)code
{
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : message ?: @"" };
    return [NSError errorWithDomain:kLGApplicationName code:code userInfo:userInfo];
}

@end

@implementation LGHTTPCredential
@synthesize credential = _credential;

- (NSURLCredential *)credential
{
    if (self.user.length && self.password.length) {
        _credential = [NSURLCredential credentialWithUser:self.user
                                                 password:self.password
                                              persistence:NSURLCredentialPersistenceNone];
    }
    return _credential;
}

- (void)handleCertificateTrustChallenge:(NSURLAuthenticationChallenge *)challenge reply:(void (^)(BOOL verifySSL))reply;
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        BOOL proceed = NO;
        _verifySSL = NO;

        SecTrustResultType secresult = kSecTrustResultInvalid;
        if (SecTrustEvaluate(challenge.protectionSpace.serverTrust, &secresult) == errSecSuccess) {
            switch (secresult) {
                case kSecTrustResultProceed: {
                    // The user told the OS to trust the cert but this is not
                    // picked up by the python-jss' request module so set verify to NO
                    _verifySSL = NO;
                    proceed = YES;
                    break;
                }
                case kSecTrustResultUnspecified: {
                    // The OS trusts this certificate implicitly.
                    _verifySSL = YES;
                    proceed = YES;
                    break;
                }

                default: {
                    SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
                    [panel setAlternateButtonTitle:@"Cancel"];

                    NSString *info = [NSString stringWithFormat:@"The certificate for this server is invalid. You might be connecting to a server pretending to be \"%@\" which could put your confidential information at risk. Would you like to connect to the server anyway?", self.serverURL.host];

                    [panel setInformativeText:info];

                    proceed = [panel runModalForTrust:challenge.protectionSpace.serverTrust
                                              message:@"AutoPkgr can't verify the identity of the server"];

                    // If elected to proceed here it is doing so with an unverified certificate so set JSS_VERIFY_SSL to NO
                    // However if "Cancel" is clicked we reset the JSS_VERIFY_SSL back to YES which will deliberately cause
                    // python-jss to fail.
                    _verifySSL = proceed ? NO : YES;
                    panel = nil;
                }
            }
        }

        if (proceed) {
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        } else {
            [challenge.sender cancelAuthenticationChallenge:challenge];
        };
        reply(_verifySSL);
    }];
}

- (void)checkCredentialsAtPath:(NSString *)path reply:(void (^)(LGHTTPCredential *, LGCredentialChallengeCode, NSError *))reply
{
     BOOL __block authWasChallenged = NO;

    // String encode the path.
    path = [path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *url = [NSURL URLWithString:path relativeToURL:self.serverURL];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 10.0;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    op.shouldUseCredentialStorage = NO;

    __block NSMutableArray *protectedSpaces = [[NSMutableArray alloc] initWithCapacity:3];

    void (^purgeProtectedSpace)() = ^void() {
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        NSURLCredentialStorage *storage = [NSURLCredentialStorage sharedCredentialStorage];

        for (NSURLProtectionSpace *space in protectedSpaces) {
            NSDictionary *credentialsDict = [storage credentialsForProtectionSpace:space];
            [credentialsDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSURLCredential *obj, BOOL *stop) {
                [storage removeCredential:obj forProtectionSpace:space];
            }];
        }
    };

    [op setWillSendRequestForAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
            [self handleCertificateTrustChallenge:challenge reply:^(BOOL verifySSL) {
                [self save];
            }];
        } else if (self.credential && challenge.previousFailureCount < 1) {
            authWasChallenged = YES;
            [challenge.sender useCredential:self.credential forAuthenticationChallenge:challenge];
            [protectedSpaces addObject:challenge.protectionSpace];
        } else {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }];

    [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        purgeProtectedSpace();

        reply(self, authWasChallenged ? kLGCredentialChallengeSuccess : kLGCredentialsNotChallenged, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        purgeProtectedSpace();
        reply(self, kLGCredentialChallengeFailed, error);
    }];

    [op start];
}

@end

@implementation LGNetMountCredential

- (void)checkCredentialsForShare:(NSString *)share reply:(void (^)(LGNetMountCredential *, LGCredentialChallengeCode, NSError *))reply
{

    // encode the share path
    NSString *remoteShare = [share stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSURL *mountURL = [NSURL URLWithString:remoteShare relativeToURL:self.serverURL];

    NSURL *mountPath = [NSURL fileURLWithPathComponents:@[ @"/Volumes", share ]];

    NSURL *remountURL;
    if ([mountPath getResourceValue:&remountURL forKey:NSURLVolumeURLForRemountingKey error:nil]) {
        if ([remountURL.host isEqualToString:mountURL.host]) {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"Could not check authentication",
                                        NSLocalizedRecoverySuggestionErrorKey : @"The server is currently mounted and credentials could not be accurately checked." };

            /* TODO: not sure if this is the correct behavior.
               This will return success, but include an error indicating that the share is alreay mounted */

            return reply(self, YES, [NSError errorWithDomain:kLGApplicationName code:-1 userInfo:userInfo]);
        }
    }

    dispatch_queue_t myQueue = dispatch_get_main_queue();
    AsyncRequestID requestID = NULL;

    NSMutableDictionary *openOptions = [@{(__bridge NSString *)kNAUIOptionKey : (__bridge NSString *)kNAUIOptionNoUI } mutableCopy];

    NSMutableDictionary *mountOptions = [@{
        (__bridge NSString *)kNetFSAlreadyMountedKey : @YES,
    } mutableCopy];

    int status = NetFSMountURLAsync((__bridge CFURLRef)mountURL,
                                    NULL,
                                    (__bridge CFStringRef)(self.user),
                                    (__bridge CFStringRef)(self.password),
                                    (__bridge CFMutableDictionaryRef)(openOptions),
                                    (__bridge CFMutableDictionaryRef)(mountOptions),
                                    &requestID,
                                    myQueue,
                                    ^(int status, AsyncRequestID requestID, CFArrayRef mountpoints) {
                                    NSError *error;
                                    if (status != 0) {
                                        unmount(mountPath.fileSystemRepresentation, 0);
                                    } else {
                                        error = [self errorWithMountCode:status];
                                    }

                                    reply(self, (status == 0 || status == 17), error);
    });

    if (status != 0) {
        reply(self, NO, [self errorWithMountCode:status]);
    }
}

- (NSError *)errorWithMountCode:(int)code
{
    NSString *errMessage = [NSString stringWithFormat:@"There was a problem checking the user credentials: %s.", strerror(code)];
    return [NSError errorWithDomain:kLGApplicationName code:code userInfo:@{ NSLocalizedDescriptionKey : errMessage }];
}

@end