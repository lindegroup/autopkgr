//
//  NSTableView+Resizing.m
//
//  Created by Eldon Ahrold on 12/2/15.
//  Copyright © 2015 EEAAPPS, Inc. All rights reserved.
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

#import "NSTableView+Resizing.h"

static const NSTimeInterval defaultDuration = 0.2f;

@implementation NSTableView (Resizing)

#pragma mark - Height
- (void)resized_HeightToFit
{
    NSInteger height = (self.numberOfRows * self.rowHeight) * 1.2;
    [self resized_Height:height];
}

- (void)resized_Height:(NSInteger)height
{
    [self resized_Height:height duration:defaultDuration];
}

- (void)resized_Height:(NSInteger)height duration:(NSTimeInterval)duration
{
    NSInteger max = ([NSScreen mainScreen].frame.size.height * 0.9);
    if (height > max) {
        height = max;
    }
    [self resize_withConstraintAttribute:NSLayoutAttributeHeight size:height duration:duration];
}

#pragma mark - Width
- (void)resized_Width:(NSInteger)width
{
    [self resized_Width:width duration:defaultDuration];
}

- (void)resized_Width:(NSInteger)width duration:(NSTimeInterval)duration
{
    [self resize_withConstraintAttribute:NSLayoutAttributeHeight size:width duration:duration];
}

#pragma mark - Base
- (void)resize_withConstraintAttribute:(NSLayoutAttribute)attribute size:(NSInteger)size duration:(NSTimeInterval)duration
{
    NSView *superview = self.superview.superview;
    superview.translatesAutoresizingMaskIntoConstraints = NO;

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"firstAttribute = %d", attribute];
    NSArray *filteredArray = [[superview constraints] filteredArrayUsingPredicate:predicate];
    NSLayoutConstraint *constraint = filteredArray.firstObject;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2f;
        context.allowsImplicitAnimation = YES;
        [constraint.animator setConstant:size];
    } completionHandler:^{
    }];
}
@end
