//
//  LGNotificationServiceWindowController.m
//  AutoPkgr
//
//  Copyright 2015 The Linde Group, Inc.
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

#import "LGNotificationServiceWindowController.h"
#import "LGBaseNotificationServiceViewController.h"
#import "LGNotificationService.h"
#import "NSTextField+animatedString.h"

@interface LGNotificationServiceWindowController ()
@property (strong, nonatomic, readonly) LGBaseNotificationServiceViewController<LGNotificationServiceProtocol> *viewController;
@end

@implementation LGNotificationServiceWindowController
@dynamic viewController;

- (instancetype)initWithViewController:(LGBaseNotificationServiceViewController *)viewController
{
    return [super initWithViewController:(NSViewController *)viewController];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.configBox.title = [[self.viewController.service class] serviceDescription] ?: @"";

    self.accessoryButton.hidden = NO;
    self.accessoryButton.title = NSLocalizedString(@"Send Test", @"Test notification button title.");
    self.accessoryButton.action = @selector(sendNotificationTest:);
    self.accessoryButton.target = self;

    NSURL *url = [[self.viewController.service class] serviceURL];
    [self configureLinkButtonForURL:url];
}

- (void)sendNotificationTest:(id)sender
{
    [self.progressSpinner startAnimation:self];
    self.infoTextField.stringValue = @"";
    self.accessoryButton.enabled = NO;

    void (^didComplete)(NSError *) = ^(NSError *error) {
        if (error) {
            [NSApp presentError:error];
        } else {
            [self.infoTextField fadeOut_withString:NSLocalizedString(@"Successfully sent test notification.", nil)];
        }

        self.accessoryButton.enabled = YES;
        [self.progressSpinner stopAnimation:self];
    };

    __weak typeof(self) weakSelf = self;
    [[self.viewController.service class] saveInfoToKeychain:self.viewController.infoOrPasswordTextField.stringValue reply:^(NSError *error) {
        __strong typeof(self) strongSelf = weakSelf;

        if (error) {
            didComplete(error);
        } else {
            [strongSelf.viewController.service sendTest:^(NSError *error) {
                didComplete(error);
            }];
        }
    }];
}

- (IBAction)close:(id)sender
{
    __weak typeof(self)weakSelf = self;
    [[self.viewController.service class] saveInfoToKeychain:self.viewController.infoOrPasswordTextField.stringValue reply:^(NSError *error) {
        [weakSelf.window close];
    }];
}


@end
