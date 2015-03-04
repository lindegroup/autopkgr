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

void postUpdateMessage(NSString *message, double progress, BOOL complete)
{
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:kLGNotificationProgressMessageUpdate
                      object:nil
                    userInfo:@{ kLGNotificationUserInfoMessage : message ?: @"",
                                kLGNotificationUserInfoProgress : @(progress),
                                kLGNotificationUserInfoSuccess : @(complete) }
          deliverImmediately:complete];
}

int main(int argc, const char *argv[])
{
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];

    if ([args boolForKey:@"runInBackground"]) {
        NSLog(@"Running AutoPkgr in background...");

        __block LGEmailer *emailer = [[LGEmailer alloc] init];

        BOOL update = [args boolForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];

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
