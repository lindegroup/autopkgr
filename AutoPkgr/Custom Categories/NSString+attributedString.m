//
//  NSString+attributedString.m
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

#import "NSString+attributedString.h"

@implementation NSString (attributedString)

- (NSAttributedString *)attributed_copy
{
    return [[NSAttributedString alloc] initWithString:self];
}

- (NSMutableAttributedString *)attributed_mutableCopy
{
    return [self.attributed_copy mutableCopy];
}

- (NSAttributedString *)attributed_with:(NSDictionary *)attributes
{
    return [[NSAttributedString alloc] initWithString:self
                                           attributes:attributes];
}

- (NSAttributedString *)attributed_withLink:(NSString *)urlString
{
    NSParameterAssert(urlString);
    return [self attributed_with:@{ NSLinkAttributeName : [NSURL URLWithString:urlString] }];
}

@end

@implementation NSMutableAttributedString (attributedString)

- (void)attributed_addAttribute:(NSString *)name value:(id)value toString:(NSString *)aString
{
    NSRange range = NSMakeRange(0, 0);
    do {
        range = NSMakeRange(range.location + range.length,
                            self.length - (range.location + range.length));

        range = [self.string rangeOfString:aString options:0 range:range];
        if (range.location != NSNotFound) {
            [self addAttribute:name value:value range:range];
        }

    } while (range.location != NSNotFound);
}

- (void)attributed_makeString:(NSString *)string linkTo:(NSString *)urlString
{
    [self attributed_addAttribute:NSLinkAttributeName value:[NSURL URLWithString:urlString] ?: urlString toString:string];
}

- (void)attributed_makeStringALink:(NSString *)string
{
    [self attributed_makeString:string linkTo:string];
}

@end
