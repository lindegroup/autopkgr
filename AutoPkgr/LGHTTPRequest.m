//
//  LGHTTPRequest.m
//  AutoPkgr
//
//  Created by Eldon on 8/9/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

@implementation LGHTTPRequest{
    AFNetworkReachabilityManager *_serverReachable;
}

- (void)checkReachabilityOfServer:(NSString *)server
                        reachable:(void (^)(BOOL))reachable
{
    NSURL *serverURL = [NSURL URLWithString:server];
    DLog(@"Checking Reachability of %@",serverURL.host);
    
    if (_serverReachable) {
        [_serverReachable stopMonitoring];
        _serverReachable = nil;
    }
    
    _serverReachable = [AFNetworkReachabilityManager managerForDomain:[serverURL host]];
    [_serverReachable setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        DLog(@"Reachability of %@: %@", serverURL.host,AFStringFromNetworkReachabilityStatus(status));
        reachable((status > 0));
    }];
    [_serverReachable startMonitoring];
}

+ (void)retrieveDistributionPoints:(NSString *)server
                          withUser:(NSString *)user
                       andPassword:(NSString *)password
                             reply:(void (^)(NSDictionary *, NSError *))reply
{
    // Setup the request
    server = [server stringByAppendingPathComponent:@"JSSResource/distributionpoints"];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:server]];
    request.timeoutInterval = 5.0;
    
    // Set up the operation
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    // Add the credential if specified
    if (user && password) {
        NSURLCredential *credential = [NSURLCredential credentialWithUser:user password:password persistence:NSURLCredentialPersistenceNone];
        [operation setCredential:credential];
    }

    [operation setWillSendRequestForAuthenticationChallengeBlock:^(NSURLConnection *connection, NSURLAuthenticationChallenge *challenge) {
        DLog(@"Got authenticaion challenge");
        if ([challenge.protectionSpace.authenticationMethod
             isEqualToString:NSURLAuthenticationMethodServerTrust]){
            {
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    if([[self class] promptForCertTrust:challenge connection:connection]){
                        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
                    }else{
                        [[challenge sender] cancelAuthenticationChallenge:challenge];
                    };
                }];
            }
        }
    }];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error = nil;
        
        NSDictionary *responseDictionary = [self jssDictioinaryRepresentation:responseObject error:&error];
        reply(responseDictionary,error);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        reply(nil,error);
    }];

    [operation start];
}

+ (BOOL)promptForCertTrust:(NSURLAuthenticationChallenge *)challenge
                connection:(NSURLConnection *)connection
{
    NSString *serverURL = connection.currentRequest.URL.host;
    SecTrustResultType secresult = kSecTrustResultInvalid;
    if (SecTrustEvaluate(challenge.protectionSpace.serverTrust, &secresult) == errSecSuccess) {
        switch (secresult) {
        case kSecTrustResultUnspecified: // The OS trusts this certificate implicitly.
        case kSecTrustResultProceed: // The user explicitly told the OS to trust it.
        {
            return YES;
        }
        default: {
            SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
            [panel setAlternateButtonTitle:@"Cancel"];
            NSString *info = [NSString stringWithFormat:@"The certificate for this server is invalid.  You might be connecting to a server pretending to be \"%@\" which could put your confidential information at risk.  Would you like to connect to the server anyway?", serverURL];

            [panel setInformativeText:info];

            BOOL button = [panel runModalForTrust:challenge.protectionSpace.serverTrust
                                          message:@"AutoPkgr can't verify the identity of the server"];
            panel = nil;
            return button;
        }
        }
    }
    return NO;
}

+ (NSDictionary *)jssDictioinaryRepresentation:(NSData *)data error:(NSError *__autoreleasing *)error
{
    if (data) {
        XMLDictionaryParser *parser = [[XMLDictionaryParser alloc] init];
        return [parser dictionaryWithData:data];
    }
    return nil;
}

@end
