//
//  NSString+attributedString.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/15/15.
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

@interface NSString (attributedString)
@property (copy, nonatomic, readonly) NSAttributedString *attributed_copy;
@property (copy, nonatomic, readonly) NSMutableAttributedString *attributed_mutableCopy;
- (NSAttributedString *)attributed_with:(NSDictionary *)attributes;
- (NSAttributedString *)attributed_withLink:(NSString *)urlString;
@end

@interface NSMutableAttributedString (attributedString)
/**
 *  Add attributes to any matching string
 *
 *  @param name   Attribute name
 *  @param value  Attribute value
 *  @param string String to match
 */
- (void)attributed_addAttribute:(NSString *)name value:(id)value toString:(NSString *)string;
- (void)attributed_makeString:(NSString *)string linkTo:(NSString *)urlString;
- (void)attributed_makeStringALink:(NSString *)string;

@end