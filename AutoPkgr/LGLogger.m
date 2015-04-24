//
//  LGLogger.c
//  AutoPkgr
//
//  Created by Eldon on 4/23/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#include "LGLogger.h"

// Debug Logging Method
void DLog(NSString *format, ...)
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"debug"]) {
        if (format) {
            va_list args;
            va_start(args, format);
            NSLogv([@"[DEBUG] " stringByAppendingString:format], args);
            va_end(args);
        }
    }
}

void DevLog(NSString *format, ...)
{
#if DEBUG
    if (format) {
        va_list args;
        va_start(args, format);
        NSLogv([@"[DEVEL] " stringByAppendingString:format], args);
        va_end(args);
    }
#endif
}