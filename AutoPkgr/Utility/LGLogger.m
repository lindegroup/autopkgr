//
//  LGLogger.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 4/23/15.
//  Copyright 2015-2016 The Linde Group, Inc.
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

static NSTimeInterval _launchProfileStartTime = 0;

static BOOL LGDebugLoggingEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"debug"];
}

NSString *quick_formatString(NSString *format, ...)
{
    NSString *string = nil;
    if (format) {
        va_list args;
        va_start(args, format);
        string = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
    }
    return string ?: format;
}

NSString *quick_pathJoin(NSArray *components)
{
    if (components.count) {
        NSMutableString *path = [[NSMutableString alloc] init];
        [components enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            if (obj.length) {
                if (![[obj substringToIndex:0] isEqualToString:@"/"]) {
                    [path appendString:@"/"];
                }
                [path appendString:obj];
            }
        }];
        return path.copy;
    }
    return nil;
}

// Debug Logging Method
void DLog(NSString *format, ...)
{
    if (LGDebugLoggingEnabled()) {
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

void LGLaunchProfileStart(void)
{
    _launchProfileStartTime = [NSDate timeIntervalSinceReferenceDate];
    DLog(@"Launch profile: +0.000s process entry");
}

void LGLaunchProfileLog(NSString *format, ...)
{
    if (!_launchProfileStartTime) {
        _launchProfileStartTime = [NSDate timeIntervalSinceReferenceDate];
    }

    if (format && LGDebugLoggingEnabled()) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);

        NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - _launchProfileStartTime;
        DLog(@"Launch profile: +%.3fs %@", elapsed, message);
    }
}
