//
//  NSButton+colored.m
//  AutoPkgr
//
//  Created by Eldon on 6/7/15.
//  Copyright 2015 Eldon Ahrold
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

#import "NSButton+colored.h"

@implementation NSButton (color)

- (void)color_title:(NSString *)title withColor:(NSColor *)color
{

    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc]
                                             initWithString:title];

    [self setTitle:attrString withColor:color];
}

- (void)color_titleColor:(NSColor *)color
{
    [self setTitle:[self.attributedTitle mutableCopy] withColor:color];
}

- (void)setTitle:(NSMutableAttributedString *)string withColor:(NSColor *)color
{

    NSInteger len = string.length;
    NSRange range = NSMakeRange(0, len);

    [string addAttribute:NSForegroundColorAttributeName
                      value:color
                      range:range];

    [string fixAttributesInRange:range];

    [self setAttributedTitle:[string copy]];
}

@end
