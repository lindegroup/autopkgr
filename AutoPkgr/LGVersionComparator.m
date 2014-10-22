//
//  LGVersionComparator.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//
//  Copyright 2014 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGVersionComparator.h"

@implementation LGVersionComparator

static int maximumValuesInVersion = 4;

+ (BOOL)isVersion:(NSString *)a greaterThanVersion:(NSString *)b
{
    // Make sure neither a or b are nil
    if (a && b) {
        NSArray *versionA = [a componentsSeparatedByString:@"."];
        versionA = [self normalizeVersionFromArray:versionA];

        NSArray *versionB = [b componentsSeparatedByString:@"."];
        versionB = [self normalizeVersionFromArray:versionB];
        for (NSInteger i = 0; i < maximumValuesInVersion; i++) {
            if ([[versionA objectAtIndex:i] integerValue] > [[versionB objectAtIndex:i] integerValue]) {
                return YES;
            } else if ([[versionA objectAtIndex:i] integerValue] < [[versionB objectAtIndex:i] integerValue]) {
                return NO;
            }
        }
    }
    return NO;
}

+ (NSArray *)normalizeVersionFromArray:(NSArray *)versionArray
{
    if ([versionArray count] < maximumValuesInVersion) {
        NSMutableArray *mutableArray = [versionArray mutableCopy];
        NSInteger difference = maximumValuesInVersion - [mutableArray count];

        for (NSInteger i = 0; i < difference; i++) {
            [mutableArray addObject:@"0"];
        }

        return [NSArray arrayWithArray:mutableArray];

    } else {

        return versionArray;
    }
}

@end
