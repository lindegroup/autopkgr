//
//  NSArray+filtered.h
//  AutoPkgr
//
//  Created by Eldon on 11/16/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (filtered)
// Returns an array with empty strings removed
- (NSArray *)filtered_noEmptyStrings;

// Returns an array with only items of the specified class.
- (NSArray *)filtered_ByClass:(Class)class;

// Verifies that an array only contains items of a specified class.
- (BOOL)filtered_containsOnlyItemsOfClass:(Class)class;

@end

