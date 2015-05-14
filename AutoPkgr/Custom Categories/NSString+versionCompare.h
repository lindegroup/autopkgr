//
//  NSString+valueCompare.h
//  AutoPkgr
//
//  Created by Eldon on 5/14/15.
//  Copyright (c) 2015 Eldon Ahrold. All rights reserved.
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

@interface NSString (versionCompare)

- (NSComparisonResult)compareToVersion:(NSString *)version;

- (BOOL)version_isGreaterThan:(NSString *)version;
- (BOOL)version_isGreaterThanOrEqualTo:(NSString *)version;
- (BOOL)version_isEqualTo:(NSString *)version;

- (BOOL)version_isLessThan:(NSString *)version;
- (BOOL)version_isLessThanOrEqualTo:(NSString *)version;

@end
