//
//  LGMacPatchIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/26/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGMacPatchIntegrationView.h"
#import "LGMacPatchIntegration.h"

#import "NSTextField+safeStringValue.h"
@interface LGMacPatchIntegrationView ()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *MacPatchURL;
@property (weak) IBOutlet NSTextField *MacPatchUserNameTF;
@property (weak) IBOutlet NSSecureTextField *MacPatchPasswordTF;
@property (weak) IBOutlet NSButton *MacPatchVerifySSLBT;

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

    _MacPatchVerifySSLBT.target = self;
    _MacPatchVerifySSLBT.action = @selector(changeSSLVerify:);
    _MacPatchVerifySSLBT.state = _defaults.MP_SSL_VERIFY;
}

- (void)changeSSLVerify:(NSButton *)sender {
    _defaults.MP_SSL_VERIFY = sender.state;
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
