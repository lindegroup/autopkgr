//
//  NSTextField+AnimatedString.m
//  Printer Portal
//
//  Created by Eldon on 6/21/15.
//  Copyright (c) 2015 Eldon Ahrold. All rights reserved.
//

#import "NSTextField+animatedString.h"
#import <Quartz/Quartz.h>

@implementation NSTextField (animatedString)

- (BOOL)fadeOut_string {
    return NO;
}

- (void)setFadeOut_string:(BOOL)fadeOut {
    if (fadeOut) {
        [self fadeOut_withDuration:1.0 delay:2.0];
    }
}

- (void)fadeOut_withString:(NSString *)aString {
    self.stringValue = aString;
    [self fadeOut_withDuration:1.0 delay:2.0];
}

- (void)fadeOut_withDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay {
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
                            } completionHandler: ^{
                                /* Set the string value to @"" so we can reset the alpha to 1.0.
                                 * If you don't do this if the string is set by another method
                                 * it's won't be visible */
                                self.stringValue = @"";
                                self.animator.alphaValue = 1.0;
                            }];
        }];
}
@end
