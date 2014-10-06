//
//  NSTextField+setStringValueSafe.m
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "NSTextField+setSafeStringValue.h"

@implementation NSTextField (setSafeStringValue)

-(NSString *)safeStringValue
{
    NSString *aString;
    if (![self.stringValue isEqualToString:@""]) {
        aString = self.stringValue;
    }
    return aString;
}

-(void)setSafeStringValue:(NSString *)aString
{
    if (aString && ![aString isEqualToString:@""]) {
        [self setStringValue:aString];
    }
}
@end
