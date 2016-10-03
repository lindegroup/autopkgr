//
//  NSTextField+animatedString.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/21/15.
//  Copyright 2015 Eldon Ahrold
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

#import "NSTextField+animatedString.h"
#import <Quartz/Quartz.h>

@implementation NSTextField (animatedString)

- (BOOL)fadeOut_string
{
    return NO;
}

- (void)setFadeOut_string:(BOOL)fadeOut
{
    if (fadeOut) {
        [self fadeOut_withDuration:1.0 delay:2.0];
    }
}

- (void)fadeOut_withString:(NSString *)aString
{
    self.stringValue = aString;
    [self fadeOut_withDuration:1.0 delay:2.0];
}

- (void)fadeOut_withDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay
{
    /* The animator requires some change in value from start to end when running
     * the animation group otherwise it immediately triggers the completionHandler */
    self.animator.alphaValue = 0.99;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = delay;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
        self.animator.alphaValue = 1.0;
    }
        completionHandler:^{
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                context.duration = duration;
                context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
                self.animator.alphaValue = 0.0;
            }
                completionHandler:^{
                    /* Set the string value to @"" so we can reset the alpha to 1.0.
                                 * If you don't do this if the string is set by another method
                                 * it's won't be visible */
                    self.stringValue = @"";
                    self.animator.alphaValue = 1.0;
                }];
        }];
}
@end
