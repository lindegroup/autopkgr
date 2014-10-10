//
//  LGAutoPkgSchedule.m
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//
//  Copyright 2014 The Linde Group, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgSchedule.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgTask.h"
#import "LGRecipes.h"
#import "LGEmailer.h"

@implementation LGAutoPkgSchedule {
    NSTimer *_timer;
}

+ (LGAutoPkgSchedule *)sharedTimer
{
    static dispatch_once_t onceToken;
    static LGAutoPkgSchedule *shared;
    dispatch_once(&onceToken, ^{
        shared = [[LGAutoPkgSchedule alloc] init];
    });
    return shared;
}

- (void)configure
{
    LGDefaults *defaults = [[LGDefaults alloc] init];
    if (defaults.checkForNewVersionsOfAppsAutomaticallyEnabled) {
        DLog(@"Stopping countdown to next scheduled AutoPkg run.");
        [self stopTimer];
        if ([defaults integerForKey:kLGAutoPkgRunInterval]) {
            double i = [defaults integerForKey:kLGAutoPkgRunInterval];
            if (i != 0) {
                NSTimeInterval ti = i * 60 * 60; // Convert hours to seconds for our time interval
                _timer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(runAutoPkg) userInfo:nil repeats:YES];
                if ([_timer isValid]) {
                    DLog(@"Starting countdown to next scheduled AutoPkg run.");
                }
            } else {
                DLog(@"i is 0 because that's what the user entered or what they entered wasn't a digit.");
            }
        } else {
            NSLog(@"The user enabled automatic checking for app updates, but didn't specify an interval.");
        }
    } else {
        DLog(@"Stopping countdown to next scheduled AutoPkg run.");
        [self stopTimer];
    }
}

- (void)stopTimer
{
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer = nil;
}

- (void)runAutoPkg
{
    
    LGDefaults *defaults = [[LGDefaults alloc] init];
    if (defaults.checkForNewVersionsOfAppsAutomaticallyEnabled) {
        NSLog(@"Beginning scheduled run of AutoPkg.");
        [_progressDelegate startProgressWithMessage:@"Starting scheduled run..."];
        NSString *recipeList = [LGRecipes recipeList];

        [LGAutoPkgTask runRecipeList:recipeList
            progress:^(NSString *message, double taskProgress) {
                [_progressDelegate updateProgress:message progress:taskProgress];
            }
            reply:^(NSDictionary *report, NSError *error) {
                NSLog(@"Scheduled run of AutoPkg complete.");
                [_progressDelegate stopProgress:error];
                LGEmailer *emailer = [LGEmailer new];
                [emailer sendEmailForReport:report error:error];
            }];
    } else {
        [self stopTimer];
    }
}

@end
