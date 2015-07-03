//
//  LGBaseNotificationServiceViewController.m
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

#import "LGBaseNotificationServiceViewController.h"
@implementation LGBaseNotificationServiceViewController
- (instancetype)init
{
    return (self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil]);
}

- (instancetype)initWithNotificationService:(id<LGNotificationServiceProtocol>)service
{
    if (self = [self init]) {
        self->_service = service;
    }
    return self;
}

- (void)awakeFromNib
{
    // During awakeFromNib
    [super awakeFromNib];
    if (self.infoOrPasswordTextField && [[self.service class] storesInfoInKeychain]) {

        if (self.infoOrPasswordTextField.action == nil) {
            self.infoOrPasswordTextField.action = @selector(updateKeychainInfo:);
            self.infoOrPasswordTextField.target = self;
        }

        [[self.service class] infoFromKeychain:^(NSString *infoOrPassword, NSError *error) {
            if (infoOrPassword.length) {
                self.infoOrPasswordTextField.stringValue = infoOrPassword;
            }
        }];
    }
}

- (IBAction)updateKeychainInfo:(id)sender
{
    if ([sender isKindOfClass:[NSTextField class]]) {
        if ([[self.service class] storesInfoInKeychain]) {
            [[self.service class] saveInfoToKeychain:self.infoOrPasswordTextField.stringValue reply:^(NSError *error) {}];
        }
    }
}

@end
