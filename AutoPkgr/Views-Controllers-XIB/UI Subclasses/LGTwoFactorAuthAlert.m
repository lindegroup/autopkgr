//
//  LGTwoFactorAuthAlert.m
//  AutoPkgr
//
//  Created by Eldon on 7/25/15.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGTwoFactorAuthAlert.h"

static int PADDING = 5;
static int TFSIZE = 30;
static int NUMBER_OF_FIELDS = 6;

@interface LGTwoFactorAuthAlert () <NSTextFieldDelegate>
@end

@implementation LGTwoFactorAuthAlert

- (instancetype)init
{

    if (self = [super init]) {
        self.messageText = NSLocalizedString(@"Enter your two-factor authentication code", @"NSAlert messageText when requesting 2FA code.");

        self.informativeText = NSLocalizedString(@"Two-factor authentication is enabled for your account. Enter your authentication code to verify your identity.", @"NSAlert informativeText when requesting 2FA code.");

        [self addButtonWithTitle:@"OK"];
        [self addButtonWithTitle:@"Cancel"];

        self.accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 250, TFSIZE + PADDING)];

        int position = round((self.accessoryView.frame.size.width - (NUMBER_OF_FIELDS * (PADDING + TFSIZE))) / 2);

        for (int i = 0; i < NUMBER_OF_FIELDS; i++) {
            NSTextField *input = [[NSTextField alloc] init];
            input.delegate = self;

            input.alignment = NSCenterTextAlignment;
            input.formatter = [[NSNumberFormatter alloc] init];

            [input.formatter setMaximumSignificantDigits:1];
            input.frame = NSMakeRect(position, 0, TFSIZE, TFSIZE);
            input.font = [NSFont systemFontOfSize:18];

            [self.accessoryView addSubview:input];
            position = (position + TFSIZE + PADDING);
        }
    }
    return self;
}

- (NSString *)authorizatoinCode
{
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:NUMBER_OF_FIELDS];
    for (NSTextField *textFiled in self.accessoryView.subviews) {
        if ([textFiled isKindOfClass:[NSTextField class]]) {
            [string appendString:textFiled.stringValue];
        }
    }
    return string.copy;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *textFiled = notification.object;
    NSNumber *n = [[NSNumberFormatter new] numberFromString:textFiled.stringValue];

    if (textFiled.stringValue.length && n) {
        [self.window selectKeyViewFollowingView:textFiled];
    }
}

@end
