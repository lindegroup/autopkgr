//
//  LGTableView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/14/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "LGTableView.h"

@implementation LGTableView

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    _contextualMenuMouseLocal = NSMakeRect(mousePoint.x, mousePoint.y, 1, 1);

    NSInteger row = [self rowAtPoint:mousePoint];

    if (theEvent.type == NSLeftMouseDown || theEvent.type == NSRightMouseDown) {
        if ([[self dataSource] respondsToSelector:@selector(contextualMenuForRow:)]) {
            return [(id<LGTableViewDataSource>)[self dataSource] contextualMenuForRow:row];
        }
    }
    return nil;
}

@end

@implementation LGClearTable
- (NSTableViewSelectionHighlightStyle)selectionHighlightStyle
{
    return NSTableViewSelectionHighlightStyleNone;
}
- (NSColor *)backgroundColor
{
    return [NSColor clearColor];
}
@end

@implementation LGInstallTableView
- (void)scrollWheel:(NSEvent *)theEvent
{
    if (self.numberOfRows > 4) {
        [super scrollWheel:theEvent];
    }
}
@end
