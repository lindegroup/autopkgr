//
//  LGLogger.c
//  AutoPkgr
//
//  Created by Eldon Ahrold on 4/23/15.
//  Copyright 2015 The Linde Group, Inc.
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

#include "LGLogger.h"

NSString *quick_formatString(NSString *format, ...){
    NSString *string = nil;
    if (format) {
        va_list args;
        va_start(args, format);
        string = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    return string ?: format;
}

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