//
//  NSArray+filtered.h
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

#import <Foundation/Foundation.h>

@interface NSArray (filtered)
// Returns an array with empty strings removed.
- (NSArray *)filtered_noEmptyStrings;

// Returns an array with only items of the specified class.
- (NSArray *)filtered_ByClass:(Class)class;

// Verifies that an array only contains items of a specified class.
- (BOOL)filtered_containsOnlyItemsOfClass:(Class)class;

@end

