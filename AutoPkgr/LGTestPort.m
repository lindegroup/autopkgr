//
//  LGTestPort.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGTestPort.h"

@implementation LGTestPort

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
{
    if ( eventCode & (NSStreamEventOpenCompleted | NSStreamEventErrorOccurred) ) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        if ( [read streamStatus] == NSStreamStatusError || [write streamStatus] == NSStreamStatusError ) {
            [center postNotificationName:kTestSmtpServerPortNotification
                                  object:self
                                userInfo:[NSDictionary dictionaryWithObject:kTestSmtpServerPortError forKey:kTestSmtpServerPortResult]];
            [self stopTest];
        } else if ( [read streamStatus] == NSStreamStatusOpen && [write streamStatus] == NSStreamStatusOpen) {
            [center postNotificationName:kTestSmtpServerPortNotification
                                  object:self
                                userInfo:[NSDictionary dictionaryWithObject:kTestSmtpServerPortSuccess forKey:kTestSmtpServerPortResult]];
            [self stopTest];
        }
    }
}

- (void)stopTest
{
    [read close];
    [write close];
    read = nil;
    write = nil;
}
                                                            
- (void)testHost:(NSHost *)host withPort:(NSInteger)port
{
    NSInputStream *tempRead;
    NSOutputStream *tempWrite;
    [NSStream getStreamsToHost:host
                          port:port
                   inputStream:&tempRead
                  outputStream:&tempWrite];
    read = tempRead;
    write = tempWrite;
    [read setDelegate:self];
    [write setDelegate:self];
    [read open];
    [write open];
    
    
    
}

@end
