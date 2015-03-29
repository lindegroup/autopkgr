//
//  NSArray+filtered.h
//  AutoPkgr
//
//  Created by Eldon on 11/16/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (filteredArray)
// Returns an array with empty strings removed
- (NSArray *)removeEmptyStrings;

// Returns an array with only items of the specified class.
- (NSArray *)filteredArrayByClass:(Class)class;

// Verifies that an array only contains items of a specified class.
- (BOOL)containsOnlyItemsOfClass:(Class)class;

@end

