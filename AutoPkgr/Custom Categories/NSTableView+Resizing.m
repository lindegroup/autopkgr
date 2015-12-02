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

@implementation NSTableView (Resizing)
- (void)resized_Height:(NSInteger)height {
    [self resize_withConstraintAttribute:NSLayoutAttributeHeight size:height];
}

- (void)resized_Width:(NSInteger)width {
    [self resize_withConstraintAttribute:NSLayoutAttributeHeight size:width];
}

- (void)resize_withConstraintAttribute:(NSLayoutAttribute)attribute size:(NSInteger)size {
    NSView *superview = self.superview.superview;
    superview.translatesAutoresizingMaskIntoConstraints = NO;

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"firstAttribute = %d", attribute];
    NSArray *filteredArray = [[superview constraints] filteredArrayUsingPredicate:predicate];
    NSLayoutConstraint *constraint = filteredArray.firstObject;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.2f;
        context.allowsImplicitAnimation = YES;
        [constraint.animator setConstant:size];
    } completionHandler: ^{}];
}
@end
