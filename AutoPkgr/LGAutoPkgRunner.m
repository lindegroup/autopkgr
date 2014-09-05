//
//  LGAutoPkgRunner.m
//  AutoPkgr
//
//  Created by James Barclay on 7/1/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGAutoPkgRunner.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGVersionComparator.h"
#import "LGApplications.h"
#import "LGEmailer.h"

#import <util.h>

@implementation LGAutoPkgRunner

- (NSArray *)getLocalAutoPkgRecipes
{
    // Set up our task, pipe, and file handle
    NSTask *autoPkgRecipeListTask = [[NSTask alloc] init];
    NSPipe *autoPkgRecipeListPipe = [NSPipe pipe];
    NSFileHandle *fileHandle = [autoPkgRecipeListPipe fileHandleForReading];

    // Set up our launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"list-recipes", nil];

    // Configure the task
    [autoPkgRecipeListTask setLaunchPath:launchPath];
    [autoPkgRecipeListTask setArguments:args];
    [autoPkgRecipeListTask setStandardOutput:autoPkgRecipeListPipe];

    // Launch the task
    [autoPkgRecipeListTask launch];
    [autoPkgRecipeListTask waitUntilExit];

    // Read our data from the fileHandle
    NSData *autoPkgRecipeListTaskData = [fileHandle readDataToEndOfFile];
    // Init our string with data from the fileHandle
    NSString *autoPkgRecipeListResults = [[NSString alloc] initWithData:autoPkgRecipeListTaskData encoding:NSUTF8StringEncoding];
    // Init our array with the string separated by newlines
    NSArray *autoPkgRecipeListArray = [autoPkgRecipeListResults componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // Strip empty strings from our array
    NSMutableArray *arrayWithoutEmptyStrings = [[NSMutableArray alloc] init];
    for (NSString *recipe in autoPkgRecipeListArray) {
        if (![recipe isEqualToString:@""]) {
            [arrayWithoutEmptyStrings addObject:recipe];
        }
    }

    return arrayWithoutEmptyStrings;
}

- (NSArray *)getLocalAutoPkgRecipeRepos
{
    // Set up our task, pipe, and file handle
    NSTask *autoPkgRepoListTask = [[NSTask alloc] init];
    NSPipe *autoPkgRepoListPipe = [NSPipe pipe];
    NSFileHandle *fileHandle = [autoPkgRepoListPipe fileHandleForReading];

    // Set up our launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"repo-list", nil];

    // Configure the task
    [autoPkgRepoListTask setLaunchPath:launchPath];
    [autoPkgRepoListTask setArguments:args];
    [autoPkgRepoListTask setStandardOutput:autoPkgRepoListPipe];

    // Launch the task
    [autoPkgRepoListTask launch];
    [autoPkgRepoListTask waitUntilExit];

    // Read our data from the fileHandle
    NSData *autoPkgRepoListTaskData = [fileHandle readDataToEndOfFile];
    // Init our string with data from the fileHandle
    NSString *autoPkgRepoListResults = [[NSString alloc] initWithData:autoPkgRepoListTaskData encoding:NSUTF8StringEncoding];
    // Init our array with the string separated by newlines
    NSArray *autoPkgRepoListArray = [autoPkgRepoListResults componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // Strip empty strings from our array
    NSMutableArray *arrayWithoutEmptyStrings = [[NSMutableArray alloc] init];
    for (NSString *repo in autoPkgRepoListArray) {
        if (![repo isEqualToString:@""]) {
            [arrayWithoutEmptyStrings addObject:repo];
        }
    }

    return arrayWithoutEmptyStrings;
}

- (void)addAutoPkgRecipeRepo:(NSString *)repoURL
{
    NSString *addString = [NSString stringWithFormat:@"Adding %@", repoURL];
    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationProgressStart
                                                        object:nil
                                                      userInfo:@{ kLGNotificationUserInfoMessage : addString }];
    // Set up task, pipe, and file handle
    NSTask *autoPkgRepoAddTask = [[NSTask alloc] init];
    NSPipe *autoPkgRepoAddPipe = [NSPipe pipe];

    // Set up launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"repo-add", [NSString stringWithFormat:@"%@", repoURL], nil];

    // Configure the task
    [autoPkgRepoAddTask setLaunchPath:launchPath];
    [autoPkgRepoAddTask setArguments:args];
    [autoPkgRepoAddTask setStandardOutput:autoPkgRepoAddPipe];
    [autoPkgRepoAddTask setStandardError:[NSPipe pipe]];

    __weak LGAutoPkgRunner *notificationObject = self;
    autoPkgRepoAddTask.terminationHandler = ^(NSTask *aTask) {
        NSError *error;
        NSDictionary *userInfo;
        if (![LGError errorWithTaskError:aTask verb:kLGAutoPkgrRepoAdd error:&error]) {
            userInfo = @{kLGNotificationUserInfoError:error};
        }
        [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationProgressStop
                                                           object:notificationObject
                                                         userInfo:userInfo];
    };

    // Launch the task
    [autoPkgRepoAddTask launch];
    [autoPkgRepoAddTask waitUntilExit];
}

- (void)removeAutoPkgRecipeRepo:(NSString *)repoURL
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationProgressStart
                                                        object:nil
                                                      userInfo:@{ kLGNotificationUserInfoMessage : @"Removing Repo" }];

    // Set up task and pipe
    NSTask *autoPkgRepoRemoveTask = [[NSTask alloc] init];
    NSPipe *autoPkgRepoRemovePipe = [NSPipe pipe];

    // Set up launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"repo-delete", [NSString stringWithFormat:@"%@", repoURL], nil];

    // Configure the task
    [autoPkgRepoRemoveTask setLaunchPath:launchPath];
    [autoPkgRepoRemoveTask setArguments:args];
    [autoPkgRepoRemoveTask setStandardOutput:autoPkgRepoRemovePipe];
    [autoPkgRepoRemoveTask setStandardError:[NSPipe pipe]];

    __weak LGAutoPkgRunner *notificationObject = self;
    autoPkgRepoRemoveTask.terminationHandler = ^(NSTask *aTask) {
        NSError *error;
        NSDictionary *userInfo;
        if (![LGError errorWithTaskError:aTask verb:kLGAutoPkgrRepoDelete error:&error]) {
            userInfo = @{kLGNotificationUserInfoError:error};
        }
        [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationProgressStop
                                                           object:notificationObject
                                                         userInfo:userInfo];
    };

    // Launch the task
    [autoPkgRepoRemoveTask launch];
    [autoPkgRepoRemoveTask waitUntilExit];
}

- (void)updateAutoPkgRecipeRepos
{
    // Set up task and pipe
    NSTask *updateAutoPkgReposTask = [[NSTask alloc] init];

    // Set up launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"repo-update", @"all", nil];

    // Configure the task
    [updateAutoPkgReposTask setLaunchPath:launchPath];
    [updateAutoPkgReposTask setArguments:args];

    updateAutoPkgReposTask.standardOutput =[NSPipe pipe];
    updateAutoPkgReposTask.standardError =[NSPipe pipe];

    updateAutoPkgReposTask.terminationHandler = ^(NSTask *aTask) {
        NSDictionary *userInfo;
        NSError *error;
        if (![LGError errorWithTaskError:aTask verb:kLGAutoPkgrRepoUpdate error:&error]) {
            userInfo = @{kLGNotificationUserInfoError:error};
        }

        [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationUpdateReposComplete
                                                           object:nil
                                                         userInfo:userInfo];
    };

    // Launch the task
    [updateAutoPkgReposTask launch];
}

- (void)runAutoPkgWithRecipeListAndSendEmailNotificationIfConfigured:(NSString *)recipeListPath
{
    // Determine version so we chan properly handle --report-plist
    BOOL autoPkgAboveV0_3_2;

    LGHostInfo *info = [LGHostInfo new];
    LGVersionComparator *comparator = [LGVersionComparator new];
    if ([comparator isVersion:info.getAutoPkgVersion greaterThanVersion:@"0.3.2"]) {
        autoPkgAboveV0_3_2 = YES;
    }

    // Set up our task, pipe, and file handle
    NSTask *autoPkgRunTask = [[NSTask alloc] init];
    autoPkgRunTask.launchPath = @"/usr/bin/python";

    autoPkgRunTask.standardError = [NSPipe pipe];

    // Set up args based on whether report is a file or piped to stdout
    NSMutableArray *args = [[NSMutableArray alloc] initWithArray:@[@"/usr/local/bin/autopkg",
                                                                   @"run",
                                                                   @"--recipe-list",
                                                                   recipeListPath,
                                                                   @"--report-plist"]];

    if (autoPkgAboveV0_3_2) {
        // Set up a pseudo terminal so stdout gets flushed and we can get status updates.
        // Concept taken from http://stackoverflow.com/a/13355870
        int fdMaster, fdSlave;

        if (openpty(&fdMaster, &fdSlave, NULL, NULL, NULL) == 0) {
            fcntl(fdMaster, F_SETFD, FD_CLOEXEC);
            fcntl(fdSlave, F_SETFD, FD_CLOEXEC);
            autoPkgRunTask.standardOutput = [[NSFileHandle alloc] initWithFileDescriptor:fdMaster closeOnDealloc:YES];
        }

        // Create a unique temp file where AutoPkg will write the plist file.
        NSString *plistFile = [NSTemporaryDirectory() stringByAppendingString:[[NSProcessInfo processInfo] globallyUniqueString]];

        // Add arg for the file path to the report-plist and turn on verbose mode.
        [args addObject:plistFile];

        // If the version of AutoPkg is > 0.3.2 we'll be able to provide lots more information
        NSString *recipeListString = [NSString stringWithContentsOfFile:recipeListPath
                                                               encoding:NSASCIIStringEncoding
                                                                  error:nil];

        NSArray *recipeListArray = [recipeListString componentsSeparatedByString:@"\n"];

        __block NSInteger installCount = 1;
        NSInteger totalCount = recipeListArray.count;

        [autoPkgRunTask.standardOutput setReadabilityHandler:^(NSFileHandle *handle) {
            NSString *string = [[NSString alloc] initWithData:[handle availableData] encoding:NSASCIIStringEncoding];

            // Strip out any new line characters so it displays better
            NSString *strippedString = [string stringByReplacingOccurrencesOfString:@"\n"
                                                                         withString:@""];

            // Set the detail string for the notification
            NSString *detailString = [NSString stringWithFormat:@"(%ld/%ld) %@", installCount, totalCount, strippedString];

            // Post notification
            if (installCount <= totalCount) {
                installCount ++;
                [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationProgressMessageUpdate
                                                                    object:nil
                                                                  userInfo:@{kLGNotificationUserInfoMessage:detailString,
                                                                             kLGNotificationUserInfoTotalRecipeCount:@(totalCount)}];
            }
        }];

    } else {
        // If still using AutoPkg v0.3.2 set up the pipe for --report-plist data
        autoPkgRunTask.standardOutput = [NSPipe pipe];
    }

    autoPkgRunTask.arguments = args;

    autoPkgRunTask.terminationHandler = ^(NSTask *aTask) {
        NSDictionary *userInfo = nil;
        NSError *error;
        if (![LGError errorWithTaskError:aTask verb:kLGAutoPkgrRun error:&error]) {
            userInfo = @{kLGNotificationUserInfoError:error};
        }

        [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationRunAutoPkgComplete
                                                           object:nil
                                                         userInfo:userInfo];

        LGDefaults *defaults = [[LGDefaults alloc] init];
        // If the autopkg run exited successfully and the send email is enabled continue
        if ([defaults sendEmailNotificationsWhenNewVersionsAreFoundEnabled]) {
            NSDictionary *report;            
            // Read our data from file if autopkg v > 0.3.2 else read from stdout filehandle
            if (autoPkgAboveV0_3_2) {
                // create the plist from the temp file
                report = [NSDictionary dictionaryWithContentsOfFile:[aTask.arguments lastObject]];
                
                // nil out the readability handler
                [aTask.standardOutput setReadabilityHandler:nil];

            } else {
                NSData *autoPkgRunReportPlistData = [[aTask.standardOutput fileHandleForReading] readDataToEndOfFile];
                // Init our string with data from the fileHandle
                NSString *autoPkgRunReportPlistString = [[NSString alloc] initWithData:autoPkgRunReportPlistData encoding:NSUTF8StringEncoding];
                if (![autoPkgRunReportPlistString isEqualToString:@""]) {
                    // Convert string back to data for plist serialization
                    NSData *plistData = [autoPkgRunReportPlistString dataUsingEncoding:NSUTF8StringEncoding];
                    // Initialize plist format
                    NSPropertyListFormat format;
                    // Initialize our dict
                    report = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];
                }
            }
            NSLog(@"This is our report: %@.", report);
            
            if (!report) {
                NSLog(@"Could not serialize the report. Error: %@.", error);
            }
            LGEmailer *emailer = [[LGEmailer alloc] init];
            [emailer sendEmailForReport:report error:error];
        }
        [aTask.standardError fileHandleForReading].readabilityHandler = nil;

        // Setting this to nil doesn't seem right, but it prevents memory leak
        [aTask setTerminationHandler:nil];
    };

    // Launch the task
    [autoPkgRunTask launch];
}

- (void)invokeAutoPkgInBackgroundThread
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    // This ensures that no more than one thread will be spawned
    // to run AutoPkg.
    [queue setMaxConcurrentOperationCount:1];
    NSInvocationOperation *task = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(runAutoPkgWithRecipeList) object:nil];
    [queue addOperation:task];
}

- (void)invokeAutoPkgRepoUpdateInBackgroundThread
{
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    // This ensures that no more than one thread will be spawned
    // to run AutoPkg repo updates.
    [queue setMaxConcurrentOperationCount:1];
    NSInvocationOperation *task = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(updateAutoPkgRecipeRepos) object:nil];
    [queue addOperation:task];
}

- (void)runAutoPkgWithRecipeList
{
    LGApplications *apps = [[LGApplications alloc] init];
    NSString *applicationSupportDirectory = [apps getAppSupportDirectory];
    NSString *recipeListFilePath = [applicationSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    __weak LGAutoPkgRunner *weakSelf = self;
    [weakSelf runAutoPkgWithRecipeListAndSendEmailNotificationIfConfigured:recipeListFilePath];
}

- (void)startAutoPkgRunTimer
{
    LGDefaults *defaults = [[LGDefaults alloc] init];

    if ([defaults checkForNewVersionsOfAppsAutomaticallyEnabled]) {
        if ([defaults integerForKey:kLGAutoPkgRunInterval]) {
            double i = [defaults integerForKey:kLGAutoPkgRunInterval];
            if (i != 0) {
                NSTimeInterval ti = i * 60 * 60; // Convert hours to seconds for our time interval
                [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(invokeAutoPkgInBackgroundThread) userInfo:nil repeats:YES];
            } else {
                NSLog(@"i is 0 because that's what the user entered or what they entered wasn't a digit.");
            }
        } else {
            NSLog(@"The user enabled automatic checking for app updates but they specified no interval.");
        }
    }
}

- (void)setLocalMunkiRepoForAutoPkg:(NSString *)localMunkiRepo
{
    CFStringRef key = (CFSTR("MUNKI_REPO"));
    // Create a CoreFoundation string reference from the
    // localMunkiRepo NSString pointer, (no need to release)
    CFStringRef val = (__bridge CFStringRef)localMunkiRepo;
    CFStringRef appID = (CFSTR("com.github.autopkg"));

    CFPreferencesSetAppValue(key, val, appID);

    // Release our key and appID refs
    CFRelease(key);
    CFRelease(appID);
}

@end
