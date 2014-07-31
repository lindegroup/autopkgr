//
//  LGVersionComparator.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGVersionComparator.h"

@implementation LGVersionComparator

static int maximumValuesInVersion = 4;

- (BOOL)isVersion:(NSString *)a greaterThanVersion:(NSString *)b
{
    // make sure neither a or b are nil
    if (a && b){
        NSArray *versionA = [a componentsSeparatedByString:@"."];
        versionA = [self normalizeVersionFromArray:versionA];

        NSArray *versionB = [b componentsSeparatedByString:@"."];
        versionB = [self normalizeVersionFromArray:versionB];
        for (NSInteger i=0; i < maximumValuesInVersion; i++) {
            if ([[versionA objectAtIndex:i] integerValue] > [[versionB objectAtIndex:i] integerValue]) {
                return YES;
            } else if ([[versionA objectAtIndex:i] integerValue] < [[versionB objectAtIndex:i] integerValue]) {
                return NO;
            }
        }
    }
    return NO;
}

- (NSArray *)normalizeVersionFromArray:(NSArray *)versionArray
{
    if ([versionArray count] < maximumValuesInVersion) {
        NSMutableArray *mutableArray = [versionArray mutableCopy];
        NSInteger difference = maximumValuesInVersion - [mutableArray count];

        for (NSInteger i=0; i < difference; i++) {
            [mutableArray addObject:@"0"];
        }

        return [NSArray arrayWithArray:mutableArray];

    } else {

        return versionArray;
    }
}

@end
