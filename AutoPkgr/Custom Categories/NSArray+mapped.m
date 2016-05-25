//
//  NSArray+mapped.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 11/5/15.
//  Copyright 2015-2016 The Linde Group, Inc.
//

#import "NSArray+mapped.h"

@implementation NSArray (mapped)
- (NSArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:self.count];
    [self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        id new = block(obj, idx);
        if (new){
            [array addObject:new];
        }
    }];
    return array.copy;
}
@end
