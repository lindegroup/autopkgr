//
//  NSTextField+AnimatedString.h
//  Printer Portal
//
//  Created by Eldon on 6/21/15.
//  Copyright (c) 2015 Eldon Ahrold. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextField (animatedString)
@property (nonatomic, assign) BOOL fadeOut_string;

-(void)fadeOut_withString:(NSString *)aString;
-(void)fadeOut_withDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay;
@end
