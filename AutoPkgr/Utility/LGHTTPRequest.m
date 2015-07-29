//
//  LGHTTPRequest.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/9/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGHTTPRequest.h"
#import "LGAutoPkgr.h"
#import "LGJSSImporterIntegration.h"
#import "LGServerCredentials.h"

#import <AFNetworking/AFNetworking.h>
#import <XMLDictionary/XMLDictionary.h>

@implementation LGHTTPRequest {
    NSMutableArray *_protectionSpaces;
}

- (void)dealloc
{
    [self resetCache];
    [self resetCredentials];
}

- (void)retrieveDistributionPoints2:(LGHTTPCredential *)credential
                              reply:(void (^)(NSDictionary *distributionPoints, NSError *error))reply;
{
    NSLog(@"server = %@", credential.serverURL);
    
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:credential.serverURL];

    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    manager.requestSerializer.timeoutInterval = 5.0;
    manager.securityPolicy = [AFSecurityPolicy defaultPolicy];
    if (credential.sslTrustSetting & (kLGSSLTrustUserExplicitTrust | kLGSSLTrustUserConfirmedTrust)) {
        // Even in the event the user has the certificate set to trust in their keychain
        // that setting doesn't seem to get picked up by python-jss' request module so set verify to NO
        manager.securityPolicy.allowInvalidCertificates = YES;
        manager.securityPolicy.validatesCertificateChain = NO;
    }
    manager.credential = credential.credential;
    manager.responseSerializer = [AFJSONResponseSerializer serializer];

    // As of 7/29/15 JAMF cloud is returning json data as text/plain
    // so handle that too.
    [manager.responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:
                                                           @"application/json",
                                                           @"text/plain", nil]];

    NSString *fullPath = [credential.serverURL.path
                          stringByAppendingPathComponent:@"JSSResource/distributionpoints"];

    [manager GET:fullPath parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        reply(responseObject, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        reply(nil, error);
    }];
}

- (void)retrieveDistributionPoints:(LGHTTPCredential *)credential
                             reply:(void (^)(NSDictionary *distributionPoints, NSError *error))reply;
{
    // Setup the request
    NSMutableString *distPointAddress = [credential.server.trailingSlashRemoved mutableCopy];
    [ distPointAddress appendString:@"/JSSResource/distributionpoints" ];

    NSURL *url = [NSURL URLWithString:distPointAddress];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Accept"];
    request.timeoutInterval = 5.0;

    // Set up the operation
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    operation.credential = credential.credential;
    AFSecurityPolicy *policy = [AFSecurityPolicy defaultPolicy];

    if (credential.sslTrustSetting & (kLGSSLTrustUserExplicitTrust | kLGSSLTrustUserConfirmedTrust)) {
        // Even in the event the user has the certificate set to trust in their keychain
        // that setting doesn't seem to get picked up by python-jss' request module so set verify to NO
        policy.allowInvalidCertificates = YES;
        policy.validatesCertificateChain = YES;
    }

    operation.securityPolicy = policy;

    [operation setWillSendRequestForAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
            [credential handleCertificateTrustChallenge:challenge reply:^(LGSSLTrustSettings trust) {}];
        } else if (credential.credential && challenge.previousFailureCount < 1) {
            [challenge.sender useCredential:credential.credential forAuthenticationChallenge:challenge];
        } else {
            [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
        }
    }];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error = nil;

        NSDictionary *responseDictionary = [self xmlToDictionary:responseObject];

        if (!responseDictionary) error = [LGError errorWithCode:kLGErrorJSSXMLSerializerError];
        reply(responseDictionary,error);
        
        [self resetCache];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        DLog(@"Response: %@",operation.response);
        NSLog(@"Error: %@",error.localizedDescription);
        if (operation.response) error = [LGError errorWithResponse:operation.response];
        reply(nil,error);
    }];

    [operation start];
}

#pragma mark - Object Conversion

- (NSDictionary *)xmlToDictionary:(id)xmlObject;
{
    NSDictionary *dictionary = nil;
    NSError *error;

    if (xmlObject) {
        XMLDictionaryParser *xmlParser = [[XMLDictionaryParser alloc] init];
        if ([xmlObject isKindOfClass:[NSXMLParser class]]) {
            dictionary = [xmlParser dictionaryWithParser:xmlObject];
        } else if ([xmlObject isKindOfClass:[NSData class]]) {
            if ((dictionary = [xmlParser dictionaryWithData:xmlObject]) == nil)
                // If the data doesn't parse as XML also try to parse as JSON.
                if ((dictionary = [NSJSONSerialization JSONObjectWithData:xmlObject options:0 error:&error]) == nil) {
                    DLog(@"%@", error);
                }
        } else if ([xmlObject isKindOfClass:[NSString class]]) {
            dictionary = [xmlParser dictionaryWithString:xmlObject];
        }
    }
    return dictionary;
}

#pragma mark - Resets

- (void)resetCache
{
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    [sharedCache removeAllCachedResponses];
}

- (void)resetCredentials
{
    for (NSURLProtectionSpace *space in _protectionSpaces) {
        NSDictionary *credentialsDict = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:space];
        if ([credentialsDict count] > 0) {
            id userName;
            NSEnumerator *userNameEnumerator = [credentialsDict keyEnumerator];
            while (userName = [userNameEnumerator nextObject]) {
                NSURLCredential *cred = [credentialsDict objectForKey:userName];
                [[NSURLCredentialStorage sharedCredentialStorage] removeCredential:cred
                                                                forProtectionSpace:space];
            }
        }
    }
}

@end
