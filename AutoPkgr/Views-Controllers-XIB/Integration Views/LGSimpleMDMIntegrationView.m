//
//  LGSimpleMDMIntegrationView.m
//  AutoPkgr
//
//  Copyright 2020 Shawn Honsberger
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


#import "LGSimpleMDMIntegration.h"
#import "LGSimpleMDMIntegrationView.h"

#import "NSTextField+safeStringValue.h"
@interface LGSimpleMDMIntegrationView () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *SimpleMDMApiKeyTF;

@property (strong) LGSimpleMDMDefaults *defaults;
@property BOOL customTokenEnabled;

@end

@implementation LGSimpleMDMIntegrationView

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    _defaults = [[LGSimpleMDMDefaults alloc] init];

    _SimpleMDMApiKeyTF.delegate = self;
    _SimpleMDMApiKeyTF.safe_stringValue = _defaults.SIMPLEMDM_API_KEY;

}

- (IBAction)tokenTypeChanged:(NSMatrix *)matrix
{
    if (matrix.selectedRow == 0) {
        _defaults.SIMPLEMDM_API_KEY = nil;
    }
    else {
        _defaults.SIMPLEMDM_API_KEY = _SimpleMDMApiKeyTF.stringValue;
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{

    // SIMPLEMDM_API_KEY
    if ([notification.object isEqualTo:_SimpleMDMApiKeyTF]) {
        _defaults.SIMPLEMDM_API_KEY = [notification.object stringValue];
    }
}
@end

