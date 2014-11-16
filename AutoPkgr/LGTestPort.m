//
//  LGTestPort.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
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
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode & (NSStreamEventOpenCompleted | NSStreamEventErrorOccurred)) {
        if ([_inputStream streamStatus] == NSStreamStatusError ||
            [_outputStream streamStatus] == NSStreamStatusError) {
            [self portTestDidCompletedWithSuccess:NO];
        } else if ([_inputStream streamStatus] == NSStreamStatusOpen &&
                   [_outputStream streamStatus] == NSStreamStatusOpen) {
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
    if (_inputStream) {
        [_inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_inputStream close];
        _inputStream = nil;
    }
    if (_outputStream) {
        [_outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream close];
        _outputStream = nil;
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
        _inputStream = tempRead;
        _outputStream = tempWrite;
        [_inputStream setDelegate:self];
        [_outputStream setDelegate:self];
        [_inputStream open];
        [_outputStream open];

        [_inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [_outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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

    // Set up the operation
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    // Since this is just a server test, we don't care about certificate validation here
    // so set up a policy that will ignore certificate trust issues.
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    policy.allowInvalidCertificates = YES;
    policy.validatesCertificateChain = NO;

    operation.securityPolicy = policy;
    [operation setRedirectResponseBlock:^NSURLRequest * (NSURLConnection * connection, NSURLRequest * request, NSURLResponse * redirectResponse) {
        NSLog(@"redirected %@",redirectResponse);
        redirectedURL = [(NSHTTPURLResponse *)redirectResponse allHeaderFields][@"Location"];
        return request;
    }];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        reply(YES,redirectedURL);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        reply(operation.response ? YES:NO,redirectedURL);
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
    [self stopTest];
}

- (void)portTestDidCompletedWithSuccess:(BOOL)success
{
    if (_reachable) {
        _reachable(success);
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationTestSmtpServerPort
                                                        object:nil
                                                      userInfo:@{ kLGNotificationUserInfoSuccess : @(success) }];

    [self stopTest];
}

@end
