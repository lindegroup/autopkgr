//
//  NSString+cleaned.h
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (cleaned)
/**
 *  (Custom Category) equivalent to stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
 */
@property (copy,nonatomic,readonly) NSString *trimmed;

/**
 * (Custom Category) convert @"" to nil
 */
@property (copy,nonatomic,readonly) NSString *blankIsNil;
@end

