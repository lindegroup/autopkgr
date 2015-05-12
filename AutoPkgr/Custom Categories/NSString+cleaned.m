//
//  NSString+cleaned.m
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "NSString+cleaned.h"

@implementation NSString (cleaned)

- (NSString *)trimmed
{
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)trailingSlashRemoved
{
    NSInteger i = 0;
    if (self.length > 2) {
        while ([self characterAtIndex:(self.length - (i + 1))] == '/') {
            i++;
        }
    }

    return [self substringToIndex:(self.length - i)];

}

- (NSString *)blankIsNil
{
    NSString *aString = self;
    if (self && [self isEqualToString:@""]) {
        aString = nil;
    }
    return aString;
}

- (NSString *)truncateToLength:(NSInteger)length
{
    if ((self.length > length) && (length > 0)) {
        NSRange stringRange = { 0, length };

        return [[self substringWithRange:stringRange] stringByAppendingString:@"..."];
    }
    return self;
}

- (NSString *)truncateToNumberOfLines:(NSInteger)count
{
    if (self.length) {
        NSArray *lines = [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        // If the count is less, we don't need to do anything just send self back
        if (lines.count > count) {
            NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, count)];
            return [[lines objectsAtIndexes:idxSet] componentsJoinedByString:@"\n"];
        }
    }
    return self;
}
@end
