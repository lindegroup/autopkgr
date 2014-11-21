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
@end

