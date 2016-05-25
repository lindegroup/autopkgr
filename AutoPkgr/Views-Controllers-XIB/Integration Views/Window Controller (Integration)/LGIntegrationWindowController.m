//
//  LGIntegrationWindowController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/7/15.
//  Copyright 2015 Eldon Ahrold
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

#import "LGIntegrationWindowController.h"
#import "LGBaseIntegrationViewController.h"
#import "LGAutoPkgr.h"

@interface LGIntegrationWindowController ()
@property (strong, nonatomic, readonly) LGBaseIntegrationViewController *viewController;
@end

@implementation LGIntegrationWindowController
@dynamic viewController;

- (instancetype)initWithViewController:(LGBaseIntegrationViewController *)viewController
{
    return [super initWithViewController:(NSViewController *)viewController];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    self.configBox.title = [self.viewController.integration.name stringByAppendingString:@" Integration"] ?: @"";

    if ([[self.viewController.integration class] isUninstallable]) {
        self.accessoryButton.hidden = NO;
        self.accessoryButton.target = self;
        self.accessoryButton.action = @selector(uninstall:);
        self.accessoryButton.title = @"Uninstall...";
    } else {
        self.accessoryButton.hidden = YES;
    }

    NSURL *url = [[self.viewController.integration class] homePage];
    [self configureLinkButtonForURL:url];

    NSString *credits = [[self.viewController.integration class] credits];
    self.infoTextField.safe_stringValue = credits;
}



- (void)uninstall:(id)sender
{
    __weak typeof(self) weakSelf = self;
    [self.viewController.integration.progressDelegate startProgressWithMessage:@"Uninstalling..."];

    [self.progressSpinner startAnimation:nil];
    [self.viewController.integration uninstall:^(NSString *message, double progress) {} reply:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf.progressSpinner stopAnimation:nil];
            if (!error) {
                [[(LGBaseIntegrationViewController *)strongSelf.viewController integration].progressDelegate stopProgress:error];
                [strongSelf.window close];
            }
        });
    }];
}

@end
