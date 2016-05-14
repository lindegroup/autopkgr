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

@property (strong) LGVirusTotalAnalyzerDefaults *defaults;
@property BOOL  customTokenEnabled;

@end

@implementation LGVirusTotalAnalyzerIntegrationView

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

    // If we're using the default API key, this should be disabled.
    // If we're using our own API key, this should be enabled and inherit whatever value is in VIRUSTOTAL_API_KEY.
    _VirusTotalApiKeyTF.enabled = NO;


    // If there is no VIRUSTOTAL_SLEEP_SECONDS preference, this defaults to 15.
    _VirusTotalSleepSecondsTF.delegate = self;
    if(_defaults.VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE != 0){
        _VirusTotalSleepSecondsTF.integerValue = _defaults.VIRUSTOTAL_SLEEP_SECONDS;
    }

    // Set up the button states.
    _VirusTotalAlwaysReportBT.state = _defaults.VIRUSTOTAL_ALWAYS_REPORT;
    _VirusTotalAutoSubmitBT.state = _defaults.VIRUSTOTAL_AUTO_SUBMIT;

    // If VIRUSTOTAL_AUTO_SUBMIT is set to NO, this field should be disabled.
    // If VIRUSTOTAL_AUTO_SUBMIT is set to YES, this should be enabled and inherit whatever value is in VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE.
    _VirusTotalAutoSubmitMaxSizeTF.enabled = _VirusTotalAlwaysReportBT.state;
    _VirusTotalAutoSubmitMaxSizeTF.delegate = self;
    if(_VirusTotalAlwaysReportBT.state){
        _VirusTotalAutoSubmitMaxSizeTF.integerValue = _defaults.VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE;
    }

}

- (IBAction)tokenTypeChanged:(NSMatrix *)matrix {
    if(matrix.selectedRow == 0){
        _defaults.VIRUSTOTAL_API_KEY = nil;
    }
}

- (IBAction)checkBoxChanged:(NSButton *)button{
    // VIRUSTOTAL_ALWAYS_REPORT
    if ([button isEqualTo:_VirusTotalAlwaysReportBT]) {
        _defaults.VIRUSTOTAL_ALWAYS_REPORT = button.state;
    }

    // VIRUSTOTAL_AUTO_SUBMIT
    if ([button isEqualTo:_VirusTotalAutoSubmitBT]) {
        _defaults.VIRUSTOTAL_AUTO_SUBMIT = button.state;
        _VirusTotalAutoSubmitMaxSizeTF.enabled = button.state;
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {

    // VIRUSTOTAL_API_KEY
    if ([notification.object isEqualTo:_VirusTotalApiKeyTF]) {
        _defaults.VIRUSTOTAL_API_KEY = [notification.object stringValue];
    }

    // VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE
    if ([notification.object isEqualTo:_VirusTotalAutoSubmitMaxSizeTF]) {
        _defaults.VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE = [notification.object integerValue];
    }

    // VIRUSTOTAL_SLEEP_SECONDS
    if ([notification.object isEqualTo:_VirusTotalSleepSecondsTF]) {
        _defaults.VIRUSTOTAL_SLEEP_SECONDS = [notification.object integerValue];
    }
}
@end
