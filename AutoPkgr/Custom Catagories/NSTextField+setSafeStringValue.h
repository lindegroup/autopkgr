//
//  NSTextField+setStringValueSafe.h
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextField (setSafeStringValue)

/**
 *  setStringValue, but will not raise when nil sent
 */
@property (copy,nonatomic) NSString *safeStringValue;
@end

