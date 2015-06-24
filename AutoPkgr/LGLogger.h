//
//  LGLogger.h
//  AutoPkgr
//
//  Created by Eldon on 4/23/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

// Shorter NSString stringWithFormat:
NSString *quick_formatString(NSString *format, ...)NS_FORMAT_FUNCTION(1, 2);

//
void DLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
void DevLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);