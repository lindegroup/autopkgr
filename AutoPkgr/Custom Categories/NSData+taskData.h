//
//  NSData+taskData.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/5/15.
//  Copyright 2015 The Linde Group, Inc.
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

@interface NSData (NSTaskData)

@property (copy, nonatomic, readonly) NSDictionary *taskData_serializedDictionary;

@property (copy, nonatomic, readonly) NSString *taskData_string;

@property (copy, nonatomic, readonly) NSArray *taskData_splitLines;

@property (assign, nonatomic, readonly) BOOL taskData_isInteractive;
- (BOOL)taskData_isInteractiveWithStrings:(NSArray *)interactiveStrings;

@property (copy, nonatomic, readonly) id taskData_serializePropertyList;
- (id)taskData_serializePropertyList:(NSPropertyListFormat *)format;

@end
