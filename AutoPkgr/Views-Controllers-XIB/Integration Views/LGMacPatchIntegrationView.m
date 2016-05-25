//
//  LGMacPatchIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/26/15.
//  Copyright 2015-2016 The Linde Group, Inc.
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

#import "LGMacPatchIntegrationView.h"
#import "LGMacPatchIntegration.h"

#import "NSTextField+safeStringValue.h"
@interface LGMacPatchIntegrationView ()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *MacPatchURL;
@property (weak) IBOutlet NSTextField *MacPatchUserNameTF;
@property (weak) IBOutlet NSSecureTextField *MacPatchPasswordTF;
@property (weak) IBOutlet NSButton *MacPatchAllowSelfSignedCertsBT;

@end

@implementation LGMacPatchIntegrationView {
    LGMacPatchDefaults *_defaults;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    _defaults = [[LGMacPatchDefaults alloc] init];

    _MacPatchURL.delegate = self;
    _MacPatchURL.safe_stringValue = _defaults.MP_URL;

    _MacPatchUserNameTF.delegate = self;
    _MacPatchUserNameTF.safe_stringValue = _defaults.MP_USER;

    _MacPatchPasswordTF.delegate = self;
    _MacPatchPasswordTF.safe_stringValue = _defaults.MP_PASSWORD;

    // This will return nil the first time (register defaults equivalent).
    if(![_defaults autoPkgDomainObject:NSStringFromSelector(@selector(MP_SSL_VERIFY))]){
        _defaults.MP_SSL_VERIFY = YES;
    }

    _MacPatchAllowSelfSignedCertsBT.target = self;
    _MacPatchAllowSelfSignedCertsBT.action = @selector(changeSSLVerify:);

    // Allowing self signed certs is the opposite of verifySSL.
    _MacPatchAllowSelfSignedCertsBT.state = !_defaults.MP_SSL_VERIFY;
}

- (void)changeSSLVerify:(NSButton *)sender {
    _defaults.MP_SSL_VERIFY = !sender.state;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    NSString *string = [notification.object stringValue];

    // URL
    if ([notification.object isEqualTo:_MacPatchURL]) {
        _defaults.MP_URL = string;
    }

    // User
    else if ([notification.object isEqualTo:_MacPatchUserNameTF]) {
        _defaults.MP_USER = string;
    }
    
    // Password
    else if ([notification.object isEqualTo:_MacPatchPasswordTF]) {
        _defaults.MP_PASSWORD = string;
    }
}
@end
