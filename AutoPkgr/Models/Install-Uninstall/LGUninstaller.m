//
//  LGUninstaller.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGUninstaller.h"
#import "LGLogger.h"
#import "LGAutoPkgrHelperConnection.h"
#import "LGAutoPkgSchedule.h"
#import "LGPasswords.h"

#import <AHLaunchCtl/AHLaunchCtl.h>
@implementation LGUninstaller {
    void (^_completionHandler)(NSError *);
}

- (void)uninstallPackagesWithIdentifiers:(NSArray *)packageIdentifiers
                                   reply:(void (^)(NSError *error))reply
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
        assert(authorization != nil);

        LGAutoPkgrHelperConnection *helperConnection = [[LGAutoPkgrHelperConnection alloc] initWithProgressDelegate:_progressDelegate];

        [helperConnection connectionError:^(NSError *error) {
            reply(error);
        }];

        [[helperConnection remoteObjectProxy] uninstallPackagesWithIdentifiers:packageIdentifiers authorization:authorization reply:^(NSArray *removed, NSArray *remain, NSError *error) {
            if (removed.count) {
                DLog(@"Successfully removed \t%@", [removed componentsJoinedByString:@"\n\t"]);
            }
            if (remain.count) {
                DLog(@"Failed to removed \t%@", [remain componentsJoinedByString:@"\n\t"]);
            }
            reply(error);
            [helperConnection closeConnection];
        }];
    }];
}

- (void)removeFilesAtPaths:(NSArray *)fileList
                     reply:(void (^)(NSError *error))reply
{
    reply(nil);
}

- (void)removePrivilegedFilesAtPaths:(NSArray *)fileList
                               reply:(void (^)(NSError *error))reply
{
    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);

    reply(nil);
}

- (void)uninstallAutoPkgr:(id)sender
{
    if ([sender respondsToSelector:@selector(enable)]) {
        [sender setEnabled:NO];
    }

    // TODO: Prompt for components.
    BOOL removeKeychain = NO;

    // Setup completion block.
    void (^didComplete)(NSError *) = ^(NSError *error) {
        if (![AHLaunchCtl uninstallHelper:kLGAutoPkgrHelperToolName
                                   prompt:NSLocalizedString(@"Remove AutoPkgr's components.", nil)
                                    error:&error]) {
            NSLog(@"A problem occurred uninstalling helper....");
        } else {
            // Remove launch at login agent.
            [LGAutoPkgSchedule launchAtLogin:NO];

            if (removeKeychain) {
                // Remove AutoPkgr.keychain file
                NSString *keychainFile = appKeychainPath();
                NSFileManager *manager = [NSFileManager defaultManager];
                if ([manager fileExistsAtPath:appKeychainPath() ]) {
                    [manager removeItemAtPath:keychainFile error:nil];
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([sender respondsToSelector:@selector(enable)]) {
                [sender setEnabled:YES];
            }

            if (error) {
                if (error.code != errAuthorizationCanceled) {
                    [NSApp presentError:error];
                }
            } else {
                // Show end alert.
                NSString *alertText = NSLocalizedString(@"Removed AutoPkgr associated files.", nil);
                NSString *defaultButton = NSLocalizedString(@"Thanks for using AutoPkgr", nil);
                NSString *infoText = NSLocalizedString(@"This includes the helper tool, launchd schedule, and other launchd plist. You can safely remove it from your Applications folder.", nil);

                NSAlert *alert = [NSAlert alertWithMessageText:alertText defaultButton:defaultButton alternateButton:nil otherButton:nil informativeTextWithFormat:@"%@", infoText];
                [alert runModal];
                [[NSApplication sharedApplication] terminate:self];
            }
        });
    };

    NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
    assert(authorization != nil);

    LGAutoPkgrHelperConnection *helperConnection = [[LGAutoPkgrHelperConnection alloc] init];

    [helperConnection connectionError:^(NSError *error) {
        didComplete(error);
    }];

    [[helperConnection remoteObjectProxy] uninstall:authorization
                                    removeKeychains:removeKeychain
                                           packages:nil
                                              reply:^(NSError *error) {
                                                  didComplete(error);
                                                  [helperConnection closeConnection];
    }];
}

@end
