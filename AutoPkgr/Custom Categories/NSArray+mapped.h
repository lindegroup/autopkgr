//
//  NSArray+mapped.h
//  AutoPkgr
//
//  Created by Eldon on 11/5/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (mapped)

- (NSArray *)mapObjectsUsingBlock:(id (^)(id obj, NSUInteger idx))block;

@end
