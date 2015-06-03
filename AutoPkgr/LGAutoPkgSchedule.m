//
//  LGAutoPkgSchedule.m
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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
#import "LGAutoPkgrHelperConnection.h"
#import <AHLaunchCtl/AHLaunchCtl.h>

NSString *const kLGLaunchedAtLogin = @"LaunchedAtLogin";

NSString *launchAgentFolderPath()
{
    return [@"~/Library/LaunchAgents" stringByExpandingTildeInPath];
}

NSString *launchAgentFilePath()
{
    NSBundle *appBundle = [NSBundle mainBundle];

    NSString *launchAgentFileName = [appBundle.bundleIdentifier stringByAppendingPathExtension:@"launcher.plist"];

    return [launchAgentFolderPath() stringByAppendingPathComponent:launchAgentFileName];
}

@implementation LGAutoPkgSchedule

+ (void)startAutoPkgSchedule:(BOOL)start scheduleOrInterval:(id)scheduleOrInterval isForced:(BOOL)forced reply:(void (^)(NSError *error))reply
{
    BOOL scheduleIsRunning = jobIsRunning(kLGAutoPkgrLaunchDaemonPlist, kAHGlobalLaunchDaemon);
    BOOL scheduleIsNumber = [scheduleOrInterval isKindOfClass:[NSNumber class]];

    if (start && scheduleIsNumber && ([scheduleOrInterval integerValue] == 0)) {
        reply([LGError errorWithCode:kLGErrorIncorrectScheduleTimerInterval]);
        return;
    }

    // Create the external form authorization data for the helper
    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);

    LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
    [helper connectToHelper];

    /* Check for two conditions, first that start was the desired action
     * And second that either the schedule is not running or we want to 
     * force a reload of the schedule such as when the interval is changed
     */
    if (start && (!scheduleIsRunning || forced)) {

        if (scheduleIsNumber) {
            // Convert seconds to hours for our time interval
            scheduleOrInterval = @([scheduleOrInterval integerValue] * 60 * 60);
        }

        NSString *program = [[NSProcessInfo processInfo] arguments].firstObject;

        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            NSLog(@"%@", error);
            reply(error);
        }] scheduleRun:scheduleOrInterval
                     user:NSUserName()
                  program:program
            authorization:authorization
                    reply:^(NSError *error) {
                        if (!error && scheduleIsNumber) {
                            NSDate *date = [NSDate dateWithTimeIntervalSinceNow:[scheduleOrInterval integerValue]];
                            NSDateFormatter *fomatter = [NSDateFormatter new];
                            [fomatter setDateStyle:NSDateFormatterShortStyle];
                            [fomatter setTimeStyle:NSDateFormatterShortStyle];
                            NSLog(@"Next scheduled AutoPkg run will occur at %@",[fomatter stringFromDate:date]);
                        }
                        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
                        reply(error);
                    }];
    } else if (scheduleIsRunning) {
        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            reply(error);
        }] removeScheduleWithAuthorization:authorization
                                      reply:^(NSError *error) {
                                          [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
                                        reply(error);
                                      }];
    } else {
        reply([LGError errorWithCode:kLGErrorIncorrectScheduleTimerInterval]);
    }
}

+ (BOOL)updateAppsIsScheduled:(id *)scheduleInterval
{
    AHLaunchJob *job = nil;
    if ((job = [AHLaunchCtl jobFromFileNamed:kLGAutoPkgrLaunchDaemonPlist inDomain:kAHGlobalLaunchDaemon])) {
        AHLaunchJobSchedule *startInterval = job.StartCalendarInterval;
        if (startInterval) {
            *scheduleInterval = startInterval;
        } else {
            NSInteger interval = (job.StartInterval == 0) ? 24 : (job.StartInterval / 60 / 60);
            if (scheduleInterval) {
                *scheduleInterval = @(interval);
            }
        }
    }

    return (job != nil);
}

+ (BOOL)launchAtLogin:(BOOL)launch
{
    AHLaunchJob *job = [AHLaunchJob new];
    job.Label = [[launchAgentFilePath() lastPathComponent] stringByDeletingPathExtension];

    // Set an extra argument here to when launched at login, so the app delegate
    // knows to defer launching the configuration window once.
    job.ProgramArguments = @[ [[NSBundle mainBundle] executablePath], kLGLaunchedAtLogin ];
    job.RunAtLoad = YES;

    NSString *launchAgentFolder = launchAgentFolderPath();
    NSString *launchAgentFile = launchAgentFilePath();

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:launchAgentFolder]) {
        [fm createDirectoryAtPath:launchAgentFolder withIntermediateDirectories:YES attributes:nil error:nil];
    }

    BOOL success = YES;
    BOOL exists = [fm fileExistsAtPath:launchAgentFile];
    if (exists) {
        success = [fm removeItemAtPath:launchAgentFile error:nil];
    }

    if (launch) {
        success = [job.dictionary writeToFile:launchAgentFile atomically:YES];
    }

    return success;
}

+ (BOOL)willLaunchAtLogin
{
    return [[NSFileManager defaultManager] fileExistsAtPath:launchAgentFilePath()];
}

@end
