//
//  LGHTTPRequest.m
//  AutoPkgr
//
//  Created by Eldon on 8/9/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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
//

#import "LGHTTPRequest.h"
#import "LGAutoPkgr.h"
#import <AFNetworking/AFNetworking.h>
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import <XMLDictionary/XMLDictionary.h>

@implementation LGHTTPRequest {
    NSMutableArray *_protectionSpaces;
}

- (void)dealloc
{
    [self resetCache];
    [self resetCredentials];
}

- (void)retrieveDistributionPoints:(NSString *)server
                          withUser:(NSString *)user
                       andPassword:(NSString *)password
                             reply:(void (^)(NSDictionary *, NSError *))reply
{
    // Setup the request
    NSString *distPointAddress = [server stringByAppendingPathComponent:@"JSSResource/distributionpoints"];
    NSURL *url = [NSURL URLWithString:distPointAddress];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0;

    // Set up the operation
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    // Add the credential if specified
    NSURLCredential *credential;
    if (![user isEqualToString:@""] && ![password isEqualToString:@""]) {
        credential = [NSURLCredential credentialWithUser:user
                                                password:password
                                             persistence:NSURLCredentialPersistenceNone];
    }

    [operation setWillSendRequestForAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
            DLog(@"Got certificate verification challenge");
            // Since this calls a SecurityInterface panel put it on the main queue
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self promptForCertTrust:challenge connection:connection];
            }];
        } else if (credential && challenge.previousFailureCount < 1) {
            DLog(@"Got authentication challenge");
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            if (!_protectionSpaces) _protectionSpaces = [[NSMutableArray alloc] init];
            [_protectionSpaces addObject:challenge.protectionSpace];
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

#pragma mark - Challenge Handlers

- (void)promptForCertTrust:(NSURLAuthenticationChallenge *)challenge
                connection:(NSURLConnection *)connection
{
    NSString *serverURL = connection.currentRequest.URL.host;
    BOOL proceed = NO;
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    SecTrustResultType secresult = kSecTrustResultInvalid;
    if (SecTrustEvaluate(challenge.protectionSpace.serverTrust, &secresult) == errSecSuccess) {
        switch (secresult) {
        case kSecTrustResultProceed: {
            // The user told the OS to trust the cert but this is not
            // picked up by the python-jss' request module so set verify to NO
            defaults.JSSVerifySSL = NO;
            proceed = YES;
            break;
        }
        case kSecTrustResultUnspecified: {
            // The OS trusts this certificate implicitly.
            defaults.JSSVerifySSL = YES;
            proceed = YES;
            break;
        }

        default: {
            SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
            [panel setAlternateButtonTitle:@"Cancel"];
            NSString *info = [NSString stringWithFormat:@"The certificate for this server is invalid. You might be connecting to a server pretending to be \"%@\" which could put your confidential information at risk. Would you like to connect to the server anyway?", serverURL];

            [panel setInformativeText:info];

            proceed = [panel runModalForTrust:challenge.protectionSpace.serverTrust
                                      message:@"AutoPkgr can't verify the identity of the server"];

            // If elected to proceed here it is doing so with an unverified certificate so set JSS_VERIFY_SSL to NO
            // However if "Cancel" is clicked we reset the JSS_VERIFY_SSL back to YES which will deliberately cause
            // python-jss to fail.
            defaults.JSSVerifySSL = proceed ? NO : YES;
            panel = nil;
        }
        }
    }
    if (proceed) {
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    } else {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    };
}

#pragma mark - Object Conversion

- (NSDictionary *)xmlToDictionary:(id)xmlObject;
{
    NSDictionary *dictionary = nil;
    if (xmlObject) {
        XMLDictionaryParser *xmlParser = [[XMLDictionaryParser alloc] init];
        if ([xmlObject isKindOfClass:[NSXMLParser class]]) {
            dictionary = [xmlParser dictionaryWithParser:xmlObject];
        } else if ([xmlObject isKindOfClass:[NSData class]]) {
            dictionary = [xmlParser dictionaryWithData:xmlObject];
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
