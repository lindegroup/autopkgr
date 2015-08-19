//
//  LGAutoPkgIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/8/15.
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

#import "LGAutoPkgIntegrationView.h"
#import "LGAutoPkgTask.h"
#import "AHHelpPopover.h"

static NSString *const kLGTokenRevokeButonTitle = @"Revoke API Token";
static NSString *const kLGTokenGenerateButonTitle = @"Generate API Token";

@interface LGAutoPkgIntegrationView ()
@property (weak) IBOutlet NSTextField *apiUsernameTF;
@property (weak) IBOutlet NSSecureTextField *apiPasswordTF;
@property (weak) IBOutlet NSButton *generateAPITokenBT;
@property (weak) IBOutlet NSButton *apiInfoHelpBT;

@property (weak) IBOutlet NSMatrix *proxySelectionMatrix;

// Proxies text field's `enabled` property is bound to this in the XIB.
@property (nonatomic) BOOL useCustomProxies;

@end

@implementation LGAutoPkgIntegrationView

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    if ([LGAutoPkgTask apiTokenFileExists:nil]) {
        _generateAPITokenBT.title = kLGTokenRevokeButonTitle;
        _generateAPITokenBT.action = @selector(deleteAPIToken:);
    }

    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    BOOL systemProxyCheck = [defaults boolForKey:@"useSystemProxies"];
    NSString *proxyCheck = [defaults objectForKey:@"HTTP_PROXY"];
    NSString *proxyCheck2 = [defaults objectForKey:@"HTTPS_PROXY"];

    if (systemProxyCheck) {
        [self.proxySelectionMatrix selectCellAtRow:1 column:0];
    } else if(proxyCheck || proxyCheck2){
        [self.proxySelectionMatrix selectCellAtRow:2 column:0];
        self.useCustomProxies = YES;
    } else {
        [self.proxySelectionMatrix selectCellAtRow:0 column:0];
    }
}

#pragma mark - Proxies
- (IBAction)changeProxySelection:(NSMatrix *)sender{
    self.useCustomProxies = sender.selectedTag;
    
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    [defaults setBool:(sender.selectedRow == 1) forKey:@"useSystemProxies"];

    if (sender.selectedRow == 0) {
        [defaults removeObjectForKey:@"HTTP_PROXY"];
        [defaults removeObjectForKey:@"HTTPS_PROXY"];
    }
}

#pragma mark - API Token
- (IBAction)generateAPIToken:(NSButton *)sender
{
    sender.enabled = NO;
    sender.title = NSLocalizedString(@"Requesting Token", @"The button title when requesting a GitHub API Token");
    [LGAutoPkgTask generateGitHubAPIToken:_apiUsernameTF.stringValue password:_apiPasswordTF.stringValue reply:^(NSError *error) {
        sender.enabled = YES;
        if (error) {
            [NSApp presentError:error];
            sender.title = kLGTokenGenerateButonTitle;
        } else {
            sender.title = kLGTokenRevokeButonTitle;
            sender.action = @selector(deleteAPIToken:);
        }
    }];
}

- (IBAction)deleteAPIToken:(NSButton *)sender
{
    sender.enabled = NO;
    sender.title = NSLocalizedString(@"Removing Token", @"The button title when removing the GitHub API Token");

    [LGAutoPkgTask deleteGitHubAPIToken:_apiUsernameTF.stringValue password:_apiPasswordTF.stringValue reply:^(NSError *error) {
        sender.enabled = YES;
        if (error) {
            [NSApp presentError:error];
            sender.title = kLGTokenRevokeButonTitle;
        } else {
            sender.title = kLGTokenGenerateButonTitle;
            sender.action = @selector(generateAPIToken:);
        }
    }];
}

- (IBAction)showTokenHelpInfo:(NSButton *)sender
{
    NSString *tokenFile = nil;
    [LGAutoPkgTask apiTokenFileExists:&tokenFile];

    NSString *settingsLink = @"https://github.com/settings/tokens";

    NSString *message = NSLocalizedString(@"helpInfoAutoPkgAPIToken",
                                    @"message presented to user with info about generating GitHub api token");

    NSMutableAttributedString *attributedHelpText = [NSString stringWithFormat:message, settingsLink, tokenFile].attributed_mutableCopy;

    [attributedHelpText attributed_makeStringALink:settingsLink];
    [attributedHelpText attributed_makeString:@"developer.github.com" linkTo:@"https://developer.github.com/v3/oauth/"];

    AHHelpPopover *popover = [[AHHelpPopover alloc] initWithSender:_apiInfoHelpBT];
    popover.attributedHelpText = attributedHelpText;
    popover.helpTitle = @"Creating a GitHub API token";

    sender.enabled = NO;
    [popover openPopoverWithCompletionHandler:^{
        sender.enabled = YES;
    }];
}
@end
