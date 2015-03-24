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

NSString *const html_openDivTabbed = @"<div class='tabbed'>";

NSString *const html_closingDiv = @"</div>";

NSString *const html_break = @"<br/>";
NSString *const html_breakTwice = @"<br/><br/>";

NSString *const html_reportCSS = @"<style> .tabbed {margin-left: 1em;}H1 {color: #376D3E;font-size: 18pt;text-decoration: underline;font-weight: bold;padding:0;margin: 0;}H2 {color: #376D3E;font-size: 14pt;text-decoration: underline;font-weight: bold;padding:0;margin: 0;}ul {list-style-type: none;padding:0;margin: 0;margin-left: 1em;}</style>";

@implementation NSString (html_report)

+ (instancetype)html_cssStringFromResourceNamed:(NSString *)cssFile bundle:(NSBundle *)bundle
{
    NSString *file = [bundle pathForResource:cssFile ofType:@"css"];
    if (file) {
        NSString *base = [self stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil];
        return [NSString stringWithFormat:@"<style>%@</style>", base];
    }
    return nil;
}

- (NSString *)html_H1
{
    return [NSString stringWithFormat:@"<H1>%@</br></H1>", self];
}

- (NSString *)html_H2
{
    return [NSString stringWithFormat:@"<H2>%@</br></H2>", self];
}

- (NSString *)html_strongStyle
{
    return [NSString stringWithFormat:@"<strong>%@</strong>", self];
}

- (NSString *)html_strongStyleWithBreak
{
    return [NSString stringWithFormat:@"<strong>%@</strong>%@", self, html_break];
}

- (NSString *)html_italicStyle
{
    return [NSString stringWithFormat:@"<i>%@</i>", self];
}

- (NSString *)html_italicStyleWithBreak
{
    return [NSString stringWithFormat:@"<i>%@</i>%@", self, html_break];
}

- (NSString *)html_withBreak
{
    return [NSString stringWithFormat:@"%@<br/>", self];
}

- (NSString *)html_withDoubleBreak
{
    return [NSString stringWithFormat:@"%@<br/><br/>", self];
}

@end
