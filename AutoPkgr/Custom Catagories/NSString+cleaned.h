//
//  NSString+cleaned.h
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

#import <Foundation/Foundation.h>

@interface NSString (cleaned)

/**
 *  (Custom Category) equivalent to stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
 */
@property (copy, nonatomic, readonly) NSString *trimmed;

/**
 * (Custom Category) convert @"" to nil
 */
@property (copy, nonatomic, readonly) NSString *blankIsNil;

- (NSString *)truncateToLength:(NSInteger)length;

@end
