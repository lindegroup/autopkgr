//
//  NSArray+html_report.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/25/15.
//  Copyright 2015-2016 The Linde Group, Inc.
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

@interface NSArray (html_report)
@property (copy, nonatomic, readonly) NSString *html_list_unordered;
@property (copy, nonatomic, readonly) NSString *html_list_ordered;

/**
 *  Generate a table from an array of dictionaries.
 *  @note Column order is not guarenteed, and determined by key order of the first dictionary.
 */
@property (copy, nonatomic, readonly) NSString *html_table;

/**
 *  Generate a table from an array of dictionaries and the corresponding headers.
 *
 *  @param headers Array of dictionaries
 *
 *  @return HTML Table string
 */
- (NSString *)html_tableWithHeaders:(NSArray *)headers;
- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClass:(NSString *)cssClass;

/**
 *  Generate a table from an array of dictionaries and set the class of a column using the corresponding header key.
 *
 *  @param headers Array of dictionaries
 *
 *  @param cssClassForColumn dictionary with the collumn class for the corresponding header key
 *
 *  @return HTML Table string
 */
- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClassForColumns:(NSDictionary *)cssClassForColumn;

- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClass:(NSString *)cssClass cssClassForColumns:(NSDictionary *)cssClassForColumn;

@end
