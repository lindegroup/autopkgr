// LGHourPickerMenu.m
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGSchedulePickerMenu.h"

@implementation LGHourPickerMenu

- (void)awakeFromNib
{
    [self removeAllItems];
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];

    int h = 0;
    for (NSString* periods in @[ formatter.AMSymbol, formatter.PMSymbol ]) {
        NSString* title = [NSString stringWithFormat:@"12:00 %@", periods];
        NSMenuItem* item = [[NSMenuItem alloc] init];
        item.title = title;
        item.keyEquivalent = @"";
        item.tag = h;
        [self addItem:item];
        h++;

        for (int i = 1; i <= 11; i++) {
            title = [NSString stringWithFormat:@"%d:00 %@", i, periods];
            item = [[NSMenuItem alloc] init];
            item.title = title;
            item.keyEquivalent = @"";
            item.tag = h;
            [self addItem:item];
            h++;
        }
    }
}

@end

@implementation LGDayPickerMenu
- (void)awakeFromNib
{
    [self removeAllItems];
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale: [NSLocale currentLocale]];
    NSArray * weekdays = [formatter weekdaySymbols];
    for (int i = 0; i < weekdays.count; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] init];
        item.title = weekdays[i];
        item.keyEquivalent = @"";
        item.tag = i;
        [self addItem:item];
    }
}
@end
