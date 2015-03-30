//
//  NSString+html_report.m
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

#import "NSString+html_report.h"

NSString *const html_openDivTabbed = @"<div class='tabbed'>\n";
NSString *const html_closingDiv = @"</div>\n";

NSString *const html_openParagraph = @"<p>\n";
NSString *const html_closeParagraph = @"</p>\n";

NSString *const html_openListUL = @"<ul>\n";
NSString *const html_closeListUL = @"</ul>\n";

NSString *const html_openListOL = @"<ol>\n";
NSString *const html_closeListOL = @"</ol>\n";

NSString *const html_break = @"<br/>\n";
NSString *const html_breakTwice = @"<br/><br/>\n";

@implementation NSString (html_report)

+ (instancetype)html_cssStringFromResourceNamed:(NSString *)cssFile bundle:(NSBundle *)bundle
{
    NSString *file = [bundle pathForResource:cssFile ofType:@"css"];
    if (file) {
        NSString *base = [self stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        return [NSString stringWithFormat:@"<style type='text/css'>\n%@\n</style>\n", base];
    }
    return nil;
}

- (NSString *)html_H1
{
    return [self stringWrappedByTag:@"H1"];
}

- (NSString *)html_H2
{
    return [self stringWrappedByTag:@"H2"];
}

- (NSString *)html_strongStyle
{
    return [self stringWithCSSClass:@"strong"];
}

- (NSString *)html_strongStyleWithBreak
{
    return self.html_strongStyle.html_withBreak;
}

- (NSString *)html_italicStyle
{
    return [self stringWrappedByTag:@"i"];
}

- (NSString *)html_italicStyleWithBreak
{
    return self.html_italicStyle.html_withBreak;
}

- (NSString *)html_paragraph
{
    return [self stringWrappedByTag:@"p"];
}

- (NSString *)html_listItem
{
    return [NSString stringWithFormat:@"    %@", [self stringWrappedByTag:@"li"]];
}

- (NSString *)html_withBreak
{
    return [NSString stringWithFormat:@"%@<br/>\n", self];
}

- (NSString *)html_withDoubleBreak
{
    return [NSString stringWithFormat:@"%@<br/><br/>\n", self];
}

#pragma mark - Methods
- (NSString *)html_link:(NSString *)link
{
    return [NSString stringWithFormat:@"<a href='%@'>%@</a>", link, self];
}

- (NSString *)html_divWithCSSClass:(NSString *)cssClass
{
    return [self html_tag:@"div" withCSSClass:cssClass];
}

- (NSString *)html_spanWithCSSClass:(NSString *)cssClass
{
    return [self html_tag:@"span" withCSSClass:cssClass];
}

- (NSString *)html_paragraphWithCSSClass:(NSString *)cssClass {
    return [self html_tag:@"p" withCSSClass:cssClass];
}

- (NSString *)html_tag:(NSString *)tag withCSSClass:(NSString *)cssClass
{
    return [NSString stringWithFormat:@"<%@ class='%@'>%@</%@>\n", tag, cssClass, self, tag];
}

#pragma Private

- (NSString *)stringWrappedByTag:(NSString *)tag
{
    return [NSString stringWithFormat:@"<%@>%@</%@>\n", tag, self, tag];
}

- (NSString *)stringWithCSSClass:(NSString *)class
{
    return [NSString stringWithFormat:@"<span class='%@'>%@</span>\n", class, self];
}

- (NSString *)stringWithID:(NSString *)html_id
{
    return [NSString stringWithFormat:@"<div id='%@'>%@</div>\n", html_id, self];
}

@end
