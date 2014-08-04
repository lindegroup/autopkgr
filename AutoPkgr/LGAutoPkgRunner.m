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
#import "LGApplications.h"
#import "LGEmailer.h"
#import "LGConstants.h"

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

    // Launch the task
    [autoPkgRepoAddTask launch];
    [autoPkgRepoAddTask waitUntilExit];
}

- (void)removeAutoPkgRecipeRepo:(NSString *)repoURL
{
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

    // Launch the task
    [autoPkgRepoRemoveTask launch];
    [autoPkgRepoRemoveTask waitUntilExit];
}

- (void)updateAutoPkgRecipeRepos
{
    // Set up task and pipe
    NSTask *updateAutoPkgReposTask = [[NSTask alloc] init];
    NSPipe *updateAutoPkgReposPipe = [NSPipe pipe];

    // Set up launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"repo-update", @"all", nil];

    // Configure the task
    [updateAutoPkgReposTask setLaunchPath:launchPath];
    [updateAutoPkgReposTask setArguments:args];
    [updateAutoPkgReposTask setStandardOutput:updateAutoPkgReposPipe];

    // Launch the task
    [updateAutoPkgReposTask launch];
}

- (void)runAutoPkgWithRecipeListAndSendEmailNotificationIfConfigured:(NSString *)recipeListPath
{
    // Set up our task, pipe, and file handle
    NSTask *autoPkgRunTask = [[NSTask alloc] init];
    NSPipe *autoPkgRunPipe = [NSPipe pipe];
    NSFileHandle *fileHandle = [autoPkgRunPipe fileHandleForReading];

    // Set up our launch path and args
    NSString *launchPath = @"/usr/bin/python";
    NSArray *args = [NSArray arrayWithObjects:@"/usr/local/bin/autopkg", @"run", @"--report-plist", @"--recipe-list", [NSString stringWithFormat:@"%@", recipeListPath], nil];

    // Configure the task
    [autoPkgRunTask setLaunchPath:launchPath];
    [autoPkgRunTask setArguments:args];
    [autoPkgRunTask setStandardOutput:autoPkgRunPipe];

    // Launch the task
    [autoPkgRunTask launch];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled]) {
        BOOL sendEmailNotificationsWhenNewVersionsAreFoundEnabled = [[defaults objectForKey:kSendEmailNotificationsWhenNewVersionsAreFoundEnabled] boolValue];
        if (sendEmailNotificationsWhenNewVersionsAreFoundEnabled) {
            // Read our data from the fileHandle
            NSData *autoPkgRunReportPlistData = [fileHandle readDataToEndOfFile];
            // Init our string with data from the fileHandle
            NSString *autoPkgRunReportPlistString = [[NSString alloc] initWithData:autoPkgRunReportPlistData encoding:NSUTF8StringEncoding];
            // Convert string back to data for plist serialization
            NSData *plistData = [autoPkgRunReportPlistString dataUsingEncoding:NSUTF8StringEncoding];
            // Initialize our error object
            NSError *error;
            // Initialize plist format
            NSPropertyListFormat format;
            // Initialize our dict
            NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];
            NSLog(@"This is our plist: %@.", plist);

            if (!plist) {
                NSLog(@"Could not serialize the plist. Error: %@.", error);
            }

            // Get arrays of new downloads/packages from the plist
            NSArray *newDownloads = [plist objectForKey:@"new_downloads"];
            NSArray *newPackages = [plist objectForKey:@"new_packages"];

            if ([newDownloads count]) {
                NSLog(@"New stuff was downloaded.");
                NSMutableArray *newDownloadsArray = [[NSMutableArray alloc] init];

                for (NSString *path in newDownloads) {
                    NSMutableDictionary *newDownloadDict = [[NSMutableDictionary alloc] init];
                    // Get just the application name from the path in the new_downloads dict
                    NSString *app = [[path lastPathComponent] stringByDeletingPathExtension];
                    // Insert the app name into the dictionary for the "app" key
                    [newDownloadDict setObject:app forKey:@"app"];

                    for (NSDictionary *dct in newPackages) {
                        NSString *pkgPath = [dct objectForKey:@"pkg_path"];

                        if ([pkgPath rangeOfString:app options:NSCaseInsensitiveSearch].location != NSNotFound && [dct objectForKey:@"version"]) {
                            NSString *version = [dct objectForKey:@"version"];
                            [newDownloadDict setObject:version forKey:@"version"];
                            break;
                        } else {
                            [newDownloadDict setObject:@"N/A" forKey:@"version"];
                        }
                    }
                    [newDownloadsArray addObject:newDownloadDict];
                }
                
                NSLog(@"New software was downloaded. Sending an email alert.");
                [self sendNewDowloadsEmail:newDownloadsArray];
                
            } else {
                NSLog(@"Nothing new was downloaded.");
            }
        }
    }
}

- (void)sendNewDowloadsEmail:(NSArray *)newDownloadsArray
{
    LGEmailer *emailer = [[LGEmailer alloc] init];

    NSMutableArray *apps = [[NSMutableArray alloc] init];

    for (NSDictionary *download in newDownloadsArray) {
        NSString *app = [download objectForKey:@"app"];
        [apps addObject:app];
    }

    // Create the subject string
    NSString *subject = [NSString stringWithFormat:@"[%@] The Following Software is Now Available for Testing (%@)", kApplicationName, [apps componentsJoinedByString:@", "]];

    // Create the message string
    NSMutableString *newDownloadsString = [NSMutableString string];
    NSEnumerator *e = [newDownloadsArray objectEnumerator];
    id dictionary;
    while ((dictionary = [e nextObject]) != nil)
        [newDownloadsString appendFormat:@"<br /><strong>%@</strong>: %@", [dictionary objectForKey:@"app"], [dictionary objectForKey:@"version"]];
    NSString *message = [NSString stringWithFormat:@"The following software is now available for testing:<br />%@", newDownloadsString];

    [emailer sendEmailNotification:subject message:message];
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
    [self runAutoPkgWithRecipeListAndSendEmailNotificationIfConfigured:recipeListFilePath];

}

- (void)startAutoPkgRunTimer
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled]) {

        BOOL checkForNewVersionsOfAppsAutomaticallyEnabled = [[defaults objectForKey:kCheckForNewVersionsOfAppsAutomaticallyEnabled] boolValue];

        if (checkForNewVersionsOfAppsAutomaticallyEnabled) {
            if ([defaults integerForKey:kAutoPkgRunInterval]) {
                double i = [defaults integerForKey:kAutoPkgRunInterval];
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
