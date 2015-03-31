//
//  NSString+html_report.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/24/15.
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

extern NSString *const html_openDivTabbed;
extern NSString *const html_closingDiv;

extern NSString *const html_openParagraph;
extern NSString *const html_closeParagraph;

extern NSString *const html_openListUL;
extern NSString *const html_closeListUL;

extern NSString *const html_openListOL;
extern NSString *const html_closeListOL;

extern NSString *const html_break;
extern NSString *const html_breakTwice;

@interface NSString (html_report)

+ (instancetype)html_cssStringFromResourceNamed:(NSString *)cssFile bundle:(NSBundle *)bundle;

@property (copy, nonatomic, readonly) NSString *html_H1;
@property (copy, nonatomic, readonly) NSString *html_H2;

@property (copy, nonatomic, readonly) NSString *html_strongStyle;
@property (copy, nonatomic, readonly) NSString *html_strongStyleWithBreak;

@property (copy, nonatomic, readonly) NSString *html_italicStyle;
@property (copy, nonatomic, readonly) NSString *html_italicStyleWithBreak;

@property (copy, nonatomic, readonly) NSString *html_paragraph;

@property (copy, nonatomic, readonly) NSString *html_listItem;

@property (copy, nonatomic, readonly) NSString *html_withBreak;
@property (copy, nonatomic, readonly) NSString *html_withDoubleBreak;

- (NSString *)html_link:(NSString *)link;

- (NSString *)html_divWithCSSClass:(NSString *)cssClass;
- (NSString *)html_spanWithCSSClass:(NSString *)cssClass;
- (NSString *)html_paragraphWithCSSClass:(NSString *)cssClass;
- (NSString *)html_tag:(NSString *)tag withCSSClass:(NSString *)cssClass;

@end
