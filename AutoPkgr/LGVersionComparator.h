//
//  LGVersionComparator.h
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGVersionComparator : NSObject

- (BOOL)isVersion:(NSString *)a greaterThanVersion:(NSString *)b;
- (NSArray *)normalizeVersionFromArray:(NSArray *)versionArray;

@end
