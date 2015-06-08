//
//  NSArray+filtered.m
//  AutoPkgr
//
//  Created by Eldon on 11/16/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "NSArray+filtered.h"

@implementation NSArray (filtered)
- (NSArray *)filtered_noEmptyStrings
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not (SELF == '' or SELF == ' ')"];
    return [self filteredArrayUsingPredicate:predicate];
}

- (NSArray *)filtered_ByClass:(Class)class{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", class];
    return [self filteredArrayUsingPredicate:classPredicate];
}

- (BOOL)filtered_containsOnlyItemsOfClass:(Class)class
{
    return ([[self filtered_ByClass:class] count] == self.count);
}

@end
