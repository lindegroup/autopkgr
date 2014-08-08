//
//  LGTestPort.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGTestPort.h"

@implementation LGTestPort {
    
}
-(void)dealloc{
    [self stopTest];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if (eventCode & (NSStreamEventOpenCompleted | NSStreamEventErrorOccurred)) {
        if ([read streamStatus] == NSStreamStatusError ||
            [write streamStatus] == NSStreamStatusError) {
            [self postTestPortNotification:kTestSmtpServerPortError];
        } else if ([read streamStatus] == NSStreamStatusOpen &&
                   [write streamStatus] == NSStreamStatusOpen) {
            [self postTestPortNotification:kTestSmtpServerPortSuccess];
        }
    }
}

- (void)stopTest
{
    if (streamTimeoutTimer) {
        [streamTimeoutTimer invalidate];
        streamTimeoutTimer = nil;
    }
    if (read) {
        [read removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [read close];
        read = nil;
    }
    if (write) {
        [write removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [write close];
        write = nil;
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
        read = tempRead;
        write = tempWrite;
        [read setDelegate:self];
        [write setDelegate:self];
        [read open];
        [write open];

        [read scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [write scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    } else {
        [self postTestPortNotification:kTestSmtpServerPortError];
    }
}

- (void)startStreamTimeoutTimer
{
    streamTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                          target:self
                                                        selector:@selector(handleStreamTimeout)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)handleStreamTimeout
{
    [self postTestPortNotification:kTestSmtpServerPortError];
    [self stopTest];
}

- (void)postTestPortNotification:(NSString *)notice
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kTestSmtpServerPortNotification
                                                        object:nil
                                                      userInfo:@{ kTestSmtpServerPortResult : notice }];
}

@end
