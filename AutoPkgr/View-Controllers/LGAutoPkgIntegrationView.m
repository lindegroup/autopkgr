//
//  LGAutoPkgIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/8/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
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
