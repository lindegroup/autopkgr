//
//  NSArray+html_report.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/25/15.
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

#import "NSArray+html_report.h"

@implementation NSArray (html_report)
- (NSString *)html_list_unordered
{
    return [self listWithType:@"ul"];
}

- (NSString *)html_list_ordered
{
    return [self listWithType:@"ol"];
}

#pragma - Private
- (NSString *)listWithType:(NSString *)listType
{
    NSMutableString *string = nil;
    if (self.count) {
        string = [NSMutableString stringWithFormat:@"<%@>\n", listType];
        for (NSString *s in self) {
            [string appendFormat:@"<li>%@</li>\n", s];
        }
        [string appendFormat:@"</%@>\n", listType];
    }
    return [string copy];
}

- (NSString *)html_table
{
    if (self.count) {
        id firstObject = [self firstObject];
        if ([firstObject isKindOfClass:[NSDictionary class]]) {
            return [self html_tableWithHeaders:[(NSDictionary *)firstObject allKeys]];
        }
    }
    return @"";
}

- (NSString *)html_tableWithHeaders:(NSArray *)headers
{
    return [self html_tableWithHeaders:headers cssClassForColumns:nil];
}

- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClass:(NSString *)cssClass
{
    return [self html_tableWithHeaders:headers cssClass:cssClass cssClassForColumns:nil];
}

- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClassForColumns:(NSDictionary *)cssClassForColumn
{
    return [self html_tableWithHeaders:headers cssClass:nil cssClassForColumns:cssClassForColumn];
}

- (NSString *)html_tableWithHeaders:(NSArray *)headers cssClass:(NSString *)cssClass cssClassForColumns:(NSDictionary *)cssClassForColumn
{
    NSMutableString *string = nil;
    if (self.count && [self.firstObject isKindOfClass:[NSDictionary class]]) {
        string = [@"<table" mutableCopy];
        if (cssClass) {
            [string appendFormat:@" class='%@'", cssClass];
        }
        
        [string appendString:@">\n"];

        [string appendString:@"    <tr>"];

        if (headers) {
            for (NSString *header in headers) {
                [string appendFormat:@"<th>%@</th>", header];
            }
        } else {
            headers = [self.firstObject allKeys];
        }

        [string appendString:@"</tr>\n"];

        for (NSDictionary *dict in self) {
            [string appendString:@"    <tr>"];
            for (NSString *header in headers) {
                NSString *td = dict[header];
                NSString *cssClass = cssClassForColumn[header];
                if (td) {
                    if (cssClass.length) {
                        [string appendFormat:@"<td class='%@'>", cssClass];
                    } else {
                        [string appendFormat:@"<td>"];
                    }
                    [string appendFormat:@"%@</td>", td];
                }
            }
            [string appendString:@"</tr>\n"];
        }
        [string appendString:@"</table>\n"];
    }
    return string ? [string copy] : @"";
}
@end
