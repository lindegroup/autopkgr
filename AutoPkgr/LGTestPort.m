//
//  LGTestPort.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGTestPort.h"
#import "LGAutoPkgr.h"

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

-(void)testServerURL:(NSString *)url reply:(void (^)(BOOL))reply{
    NSURL *serverURL = [NSURL URLWithString:url];
    NSHost *host = [NSHost hostWithName:[serverURL host]];
    NSNumber *port = [serverURL port];
    
    // if no port specified set to defaults
    if (!port) {
        if ([serverURL.scheme isEqualToString:@"http" ]) {
            port = @(80);
        } else if ([serverURL.scheme isEqualToString:@"https"]) {
            port = @(443);
        }
    }
    
    if (host && port) {
        _reachable = reply;
        [self testHost:host withPort:[port integerValue]];
    } else {
        reply(NO);
    }
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
                                                      userInfo:@{ kLGNotificationUserInfoSuccess : @(success)}];
    
    [self stopTest];
}

@end
