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
#import "LGAutoPkgrHelperConnection.h"


int main(int argc, const char *argv[])
{
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];

    if ([args boolForKey:@"runInBackground"]) {
        NSLog(@"Running AutoPkgr in background...");

        __block BOOL completionMessageSent = NO;
        BOOL update = [args boolForKey:kLGCheckForRepoUpdatesAutomaticallyEnabled];

        LGAutoPkgTaskManager *manager = [[LGAutoPkgTaskManager alloc] init];

        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];

        [[helper.connection remoteObjectProxy] sendMessageToMainApplication:@"Running AutoPkg in background..."
                                                                   progress:0
                                                                      error:nil
                                                                      state:kLGAutoPkgProgressStart];

        [manager setProgressUpdateBlock:^(NSString *message, double progress) {
            [[helper.connection remoteObjectProxy] sendMessageToMainApplication:message
                                                                       progress:progress
                                                                          error:nil
                                                                       state:kLGAutoPkgProgressProcessing];
        }];

        [manager runRecipeList:[LGRecipes recipeList]
                    updateRepo:update
                         reply:^(NSDictionary *report, NSError *error) {
                             [[helper.connection remoteObjectProxy] sendMessageToMainApplication:nil
                                                                                        progress:100
                                                                                           error:error
                                                                                        state:kLGAutoPkgProgressComplete];
                             // Wrap up the progress messaging...
                             completionMessageSent = YES;
                             if (!completionMessageSent) {
                                 [[helper.connection remoteObjectProxy] sendMessageToMainApplication:nil
                                                                                            progress:100
                                                                                               error:nil
                                                                                               state:kLGAutoPkgProgressComplete];
                             }

                             LGEmailer *emailer = [[LGEmailer alloc] init];

                             [emailer setReplyBlock:^(NSError *mailErr) {
                                 NSLog(@"AutoPkgr background run complete.");
                                 exit((int)error.code);
                             }];

                             [emailer sendEmailForReport:report error:error];

                         }];

        [[NSRunLoop currentRunLoop] run];
        return 0;

    } else {
        return NSApplicationMain(argc, argv);
    }
}
