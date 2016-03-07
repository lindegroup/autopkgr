//
//  LGVirusTotalAnalyzerIntegrationView.m
//  AutoPkgr
//
//  Copyright 2016 Elliot Jordan
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

#import "LGVirusTotalAnalyzerIntegrationView.h"
#import "LGVirusTotalAnalyzerIntegration.h"

#import "NSTextField+safeStringValue.h"
@interface LGVirusTotalAnalyzerIntegrationView ()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *VirusTotalApiKeyTF;
@property (weak) IBOutlet NSButton *VirusTotalAlwaysReportBT;
@property (weak) IBOutlet NSButton *VirusTotalAutoSubmitBT;
@property (weak) IBOutlet NSTextField *VirusTotalAutoSubmitMaxSizeTF;
@property (weak) IBOutlet NSTextField *VirusTotalSleepSecondsTF;

@end

@implementation LGVirusTotalAnalyzerIntegrationView {
    LGVirusTotalAnalyzerDefaults *_defaults;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    _defaults = [[LGVirusTotalAnalyzerDefaults alloc] init];

    _VirusTotalApiKeyTF.delegate = self;
    _VirusTotalApiKeyTF.safe_stringValue = _defaults.VIRUSTOTAL_API_KEY;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSString *string = [notification.object stringValue];

    // VIRUSTOTAL_API_KEY
    if ([notification.object isEqualTo:_VirusTotalApiKeyTF]) {
        _defaults.VIRUSTOTAL_API_KEY = string;
    }
}
@end
