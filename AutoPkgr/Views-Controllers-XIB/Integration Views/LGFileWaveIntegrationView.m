//
//  LGFileWaveIntegrationView.m
//  AutoPkgr
//
//  Copyright 2015 Elliot Jordan
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

#import "LGAutoPkgTask.h"
#import "LGFileWaveIntegration.h"
#import "LGFileWaveIntegrationView.h"
#import "NSImage+statusLight.h"
#import "NSTextField+animatedString.h"
#import "NSTextField+safeStringValue.h"

@interface LGFileWaveIntegrationView () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *FW_SERVER_HOST;
@property (weak) IBOutlet NSTextField *FW_SERVER_PORT;
@property (weak) IBOutlet NSTextField *FW_ADMIN_USER;
@property (weak) IBOutlet NSSecureTextField *FW_ADMIN_PASSWORD;
@property (weak) IBOutlet NSButton *FWToolVerify;
@property (weak) IBOutlet NSImageView *statusImage;
@property (weak) IBOutlet NSTextField *statusLabel;

@end

@implementation LGFileWaveIntegrationView {
    LGFileWaveDefaults *_defaults;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    _defaults = [[LGFileWaveDefaults alloc] init];

    _FW_SERVER_HOST.delegate = self;
    _FW_SERVER_HOST.safe_stringValue = _defaults.FW_SERVER_HOST;

    _FW_SERVER_PORT.delegate = self;
    _FW_SERVER_PORT.safe_stringValue = _defaults.FW_SERVER_PORT;

    _FW_ADMIN_USER.delegate = self;
    _FW_ADMIN_USER.safe_stringValue = _defaults.FW_ADMIN_USER;

    _FW_ADMIN_PASSWORD.delegate = self;
    _FW_ADMIN_PASSWORD.safe_stringValue = _defaults.FW_ADMIN_PASSWORD;
    _statusImage.hidden = NO;
}

- (IBAction)FWToolVerify:(NSButton *)sender
{
    // Run `autopkg run FWTool.recipe` and make sure that it verifies.
    sender.state = NSOffState;
    [self.progressSpinner startAnimation:nil];
    _statusImage.hidden = YES;
    [LGAutoPkgTask runRecipes:@[ @"FWTool.filewave.recipe" ]
                     progress:nil
                        reply:^(NSDictionary *results, NSError *error) {
                            sender.state = NSOnState;
                            _statusImage.hidden = NO;
                            if (error) {
                                _statusImage.image = [NSImage LGStatusUnavailable];
                                [_statusLabel fadeOut_withString:error.localizedRecoverySuggestion];
                            }
                            else {
                                _statusImage.image = [NSImage LGStatusAvailable];
                                [_statusLabel fadeOut_withString:NSLocalizedString(@"Successfully verified FileWave settings", nil)];
                            }

                            [self.progressSpinner stopAnimation:nil];

                        }];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSString *string = [notification.object stringValue];

    // URL
    if ([notification.object isEqualTo:_FW_SERVER_HOST]) {
        _defaults.FW_SERVER_HOST = string;
    }

    // Port
    if ([notification.object isEqualTo:_FW_SERVER_PORT]) {
        _defaults.FW_SERVER_PORT = string;
    }

    // User
    else if ([notification.object isEqualTo:_FW_ADMIN_USER]) {
        _defaults.FW_ADMIN_USER = string;
    }

    // Password
    else if ([notification.object isEqualTo:_FW_ADMIN_PASSWORD]) {
        _defaults.FW_ADMIN_PASSWORD = string;
    }
}
@end
