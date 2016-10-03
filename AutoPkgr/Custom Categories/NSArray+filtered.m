//
//  NSArray+filtered.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 11/16/14.
//  Copyright 2014-2016 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "NSArray+filtered.h"

@implementation NSArray (filtered)
- (NSArray *)filtered_noEmptyStrings
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not (SELF == '' or SELF == ' ')"];
    return [self filteredArrayUsingPredicate:predicate];
}

- (NSArray *)filtered_ByClass:(Class) class
{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", class];
    return [self filteredArrayUsingPredicate:classPredicate];
}

- (BOOL)filtered_containsOnlyItemsOfClass:(Class) class
{
    return ([[self filtered_ByClass:class] count] == self.count);
}

@end
