//
//  NSArray+filtered.m
//  AutoPkgr
//
//  Created by Eldon on 11/16/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "NSArray+filtered.h"

@implementation NSArray (filteredArray)
- (NSArray *)removeEmptyStrings
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not (SELF == '' or SELF == ' ')"];
    return [self filteredArrayUsingPredicate:predicate];
}

- (NSArray *)filteredArrayByClass:(Class)class{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", class];
    return [self filteredArrayUsingPredicate:classPredicate];
}

- (BOOL)containsOnlyItemsOfClass:(Class)class
{
    return ([[self filteredArrayByClass:class] count] == self.count);
}

@end
