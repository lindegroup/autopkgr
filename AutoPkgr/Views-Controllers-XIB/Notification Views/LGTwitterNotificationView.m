//
//  LGTwitterNotificationView.m
//  AutoPkgr
//
//  Created by James Barclay on 8/11/15.
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

#import <Accounts/Accounts.h>
#import "LGTwitterNotificationView.h"
#import "LGTwitterNotification.h"

@interface LGTwitterNotificationView ()

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, retain) NSArray *osxTwitterAccounts;
@property (nonatomic, assign) IBOutlet NSArrayController *osxTwitterAccountsController;

@end

@implementation LGTwitterNotificationView

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    self.accountStore = [[ACAccountStore alloc] init];

    ACAccountType *twitterAccountType = [_accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];

    [_accountStore requestAccessToAccountsWithType:twitterAccountType
                                           options:nil
                                        completion:^(BOOL granted, NSError *error) {
        if (granted == NO) return;
        self.osxTwitterAccounts = [_accountStore accountsWithAccountType:twitterAccountType];
    }];
}

- (IBAction)openInternetAccountsPrefs:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:@"/System/Library/PreferencePanes/InternetAccounts.prefPane"]];
}

@end
