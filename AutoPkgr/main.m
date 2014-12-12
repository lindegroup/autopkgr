//
//  main.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
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

#import <Cocoa/Cocoa.h>
#import "LGAutoPkgTask.h"
#import "LGRecipes.h"
#import "LGEmailer.h"
#import "LGAutoPkgr.h"

int main(int argc, const char *argv[])
{
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    if ([args boolForKey:@"runInBackground"]) {
        NSLog(@"Running AutoPkgr in background...");

        __block LGEmailer *emailer = [[LGEmailer alloc] init];
        LGDefaults *defaults = [LGDefaults standardUserDefaults];
        LGAutoPkgTaskManager *manager = [[LGAutoPkgTaskManager alloc] init];
        [manager runRecipeList:[LGRecipes recipeList]
                    updateRepo:defaults.checkForRepoUpdatesAutomaticallyEnabled
                         reply:^(NSDictionary *report, NSError *error) {
            [emailer sendEmailForReport:report error:error];
                         }];

        while (emailer && !emailer.complete) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    } else {
        return NSApplicationMain(argc, argv);
    }
}

