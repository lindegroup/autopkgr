//
//  NSString+cleaned.m
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "NSString+cleaned.h"

@implementation NSString (cleaned)
- (NSString *)trimmed
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

-(NSString *)blankIsNil
{
    NSString *aString = self;
    if (self && [self isEqualToString:@""]) {
        aString = nil;
    }
    return aString;
}
@end
