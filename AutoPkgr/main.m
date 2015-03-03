//
//  main.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
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

#import <Cocoa/Cocoa.h>
#import "LGAutoPkgTask.h"
#import "LGRecipes.h"
#import "LGEmailer.h"
#import "LGAutoPkgr.h"
#import <crt_externs.h>

void postUpdateMessage(NSString *message, double progress, BOOL complete)
{
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:kLGNotificationProgressMessageUpdate
                      object:nil
                    userInfo:@{ kLGNotificationUserInfoMessage : message ?: @"",
                                kLGNotificationUserInfoProgress : @(progress),
                                kLGNotificationUserInfoSuccess : @(complete) }];
}

void hardSyncPreferences()
{
    // This is an extremely ugly hack, but for some reason, cfprefsd is not
    // reliably picking up changes when the background run is executed by launchd.
    // We're stuck syncing directly from the file.
    //
    // Only ever run this for the background run!!!

    // Hard sync AutoPkgr
    NSDictionary *autoPkgrDict = [NSDictionary dictionaryWithContentsOfFile:[@"~/Library/Preferences/com.lindegroup.AutoPkgr.plist" stringByExpandingTildeInPath]];

    CFPreferencesSetMultiple((__bridge CFDictionaryRef)autoPkgrDict,
                             NULL,
                             kCFPreferencesCurrentApplication,
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost);

    // Hard sync AutoPkg
    NSDictionary *autoPkgDict = [NSDictionary dictionaryWithContentsOfFile:[@"~/Library/Preferences/com.github.autopkg.plist" stringByExpandingTildeInPath]];

    CFPreferencesSetMultiple((__bridge CFDictionaryRef)autoPkgDict,
                             NULL,
                             (__bridge CFStringRef)(kLGAutoPkgPreferenceDomain),
                             kCFPreferencesCurrentUser,
                             kCFPreferencesAnyHost);
}


void fixYosemiteDuplicateEnvKeys(){
    // Since this seems to be a Yosemite‎
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber10_9_2) {
        DLog(@"Checking for duplicate env keys...");
        // This fix is attributed to http://tex.stackexchange.com/a/208182

        // http://lists.apple.com/archives/cocoa-dev/2011/Jan/msg00169.html
        signal(SIGPIPE, SIG_IGN);

        char ***original_env = _NSGetEnviron();
        unsigned int idx, original_count = 0;
        char **env = *original_env;

        // count items in the original environment
        while (NULL != *env) {
            original_count++;
            env++;
        }

        /*
         Make a copy of the environment, but don't worry about
         NULL-terminating this array; we'll access it by index.
         */
        char **new_env = calloc(original_count, sizeof(char *));
        env = *original_env;
        for (idx = 0; idx < original_count; idx++)
            new_env[idx] = strdup(env[idx]);

        /*
         This should be only half the length of the original
         environment, as long as we have this bug.
         */
        char **keys_seen = calloc(original_count, sizeof(char *));
        unsigned number_of_keys_seen = 0;

        // iterate our copy of environ, not the original
        for (idx = 0; idx < original_count; idx++) {

            char *key, *value = new_env[idx];
            key = strsep(&value, "=");

            if (NULL != key && NULL != value) {

                bool duplicate_key = false;
                unsigned sidx;
                /*
                 A linear search is okay, since the number of keys is small
                 and this is a one-time cost.
                 */
                for (sidx = 0; sidx < number_of_keys_seen; sidx++) {

                    if (strcmp(key, keys_seen[sidx]) == 0) {
                        duplicate_key = true;
                        break;
                    }
                }

                if (false == duplicate_key) {
                    (void) unsetenv(key);
                    setenv(key, value, 1);
                    keys_seen[number_of_keys_seen] = strdup(key);
                    number_of_keys_seen++;
                } else {
                    NSLog(@"[OSX 10.10 BUG] Found a duplicate env key %s = %s", key, value );
                }
            }

            // strdup'ed, and we're not using it again
            free(new_env[idx]);

        }

        free(new_env);

        // free each of these strdup'ed keys
        for (idx = 0; idx < number_of_keys_seen; idx++)
            free(keys_seen[idx]);
        free(keys_seen);
    }
}


int main(int argc, const char *argv[])
{

    fixYosemiteDuplicateEnvKeys();
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];

    if ([args boolForKey:@"runInBackground"]) {
        hardSyncPreferences();
        NSLog(@"Running AutoPkgr in background...");

        __block LGEmailer *emailer = [[LGEmailer alloc] init];

        BOOL update =  [args boolForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];

        LGAutoPkgTaskManager *manager = [[LGAutoPkgTaskManager alloc] init];

        [manager setProgressUpdateBlock:^(NSString *message, double progress) {
            postUpdateMessage(message, progress, NO);
        }];

        [manager runRecipeList:[LGRecipes recipeList]
                    updateRepo:update
                         reply:^(NSDictionary *report, NSError *error) {
                             postUpdateMessage(nil, 0, YES);
            [emailer sendEmailForReport:report error:error];
                         }];

        while (emailer && !emailer.complete) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }

        NSLog(@"AutoPkg background run complete.");
        return 0;
        
    } else {
        return NSApplicationMain(argc, argv);
    }
}
