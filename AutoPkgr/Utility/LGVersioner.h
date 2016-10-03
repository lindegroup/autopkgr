//
//  LGVersioner.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 12/9/14.
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

extern NSString *const kLGVersionerAppKey;
extern NSString *const kLGVersionerVersionKey;

@interface LGVersioner : NSObject

/**
 *  Array of dictionaries. Each dictionary has two keys
 *  kLGVersionerAppKey representing the Application Name
 *  kLGVersionerVersionKey represesenting the best guess at a version string
 */
@property (copy, nonatomic, readonly) NSArray *currentResults;

/**
 *  Determine if string has information relevant to determining the version of a particular app
 *
 *  @param string string to parse
 */
- (void)parseString:(NSString *)string;

@end
