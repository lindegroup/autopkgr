//
//  LGTestPort.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
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
//  limitations under the License.
//

#import "LGTestPort.h"
#import "LGAutoPkgr.h"
#import <AFNetworking/AFNetworking.h>

@interface LGTestPort ()
@property (strong, nonatomic) NSInputStream *inputStream;
@property (strong, nonatomic) NSOutputStream *outputStream;
@property (strong, nonatomic) NSTimer *streamTimeoutTimer;

@end

@implementation LGTestPort {
    void (^_reachable)(BOOL);
}

- (void)dealloc
{
    [self stopTest];
    NSLog(@"Stopping Port Test.");
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode & (NSStreamEventOpenCompleted | NSStreamEventErrorOccurred)) {
        if ([self.inputStream streamStatus] == NSStreamStatusError ||
            [self.outputStream streamStatus] == NSStreamStatusError) {
            [self portTestDidCompletedWithSuccess:NO];
        } else if ([self.inputStream streamStatus] == NSStreamStatusOpen &&
                   [self.outputStream streamStatus] == NSStreamStatusOpen) {
            [self portTestDidCompletedWithSuccess:YES];
        }
    }
}

- (void)stopTest
{
    if (_streamTimeoutTimer) {
        [_streamTimeoutTimer invalidate];
        _streamTimeoutTimer = nil;
    }

    if (self.inputStream) {

        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream close];
        self.inputStream = nil;
    }
    if (self.outputStream) {
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream close];
        self.outputStream = nil;
    }
}

- (void)testHost:(NSHost *)host withPort:(NSInteger)port
{
    NSInputStream *tempRead;
    NSOutputStream *tempWrite;

    [NSStream getStreamsToHost:host
                          port:port
                   inputStream:&tempRead
                  outputStream:&tempWrite];

    if (tempRead && tempWrite) {
        [self startStreamTimeoutTimer];

        self.inputStream = tempRead;
        self.outputStream = tempWrite;
        [self.inputStream setDelegate:self];
        [self.outputStream setDelegate:self];
        [self.inputStream open];
        [self.outputStream open];

        [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        [self portTestDidCompletedWithSuccess:NO];
    }
}

- (void)testServerURL:(NSString *)url reply:(void (^)(BOOL, NSString *))reply
{
    NSURL *serverURL = [NSURL URLWithString:url];
    __block NSString *redirectedURL = nil;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:serverURL];
    request.timeoutInterval = 5.0;
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;

    // Set up the operation
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    // Since this is just a server test, we don't care about certificate validation here
    // so set up a policy that will ignore certificate trust issues.
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    policy.allowInvalidCertificates = YES;
    policy.validatesCertificateChain = NO;

    operation.securityPolicy = policy;
    operation.shouldUseCredentialStorage = NO;
    
    [operation setRedirectResponseBlock:^NSURLRequest * (NSURLConnection * connection, NSURLRequest * request, NSURLResponse * redirectResponse) {
        if (redirectResponse) {
            DLog(@"redirected %@",redirectResponse);
        }
        redirectedURL = [(NSHTTPURLResponse *)redirectResponse allHeaderFields][@"Location"];
        return request;
    }];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        reply(YES, redirectedURL);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        reply(operation.response ? YES:NO, redirectedURL);
    }];

    [operation start];
}

- (void)startStreamTimeoutTimer
{
    _streamTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                           target:self
                                                         selector:@selector(handleStreamTimeout)
                                                         userInfo:nil
                                                          repeats:NO];
}

- (void)handleStreamTimeout
{
    [self portTestDidCompletedWithSuccess:NO];
}

- (void)portTestDidCompletedWithSuccess:(BOOL)success
{
    if (_reachable) {
        _reachable(success);
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationTestSmtpServerPort
                                                        object:nil
                                                      userInfo:@{ kLGNotificationUserInfoSuccess : @(success) }];
}

@end
