//
//  LGInstallViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.//

#import "LGInstallViewController.h"
#import "LGAutoPkgr.h"

#import "LGAutoPkgSchedule.h"
#import "LGToolManager.h"
#import "LGDisplayStatusDelegate.h"
#import "LGTableCellViews.h"

@interface LGInstallViewController () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation LGInstallViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    if (!self.awake) {
        self.awake = YES;
        // Set launch at login button
        _launchAtLoginButton.state = [LGAutoPkgSchedule willLaunchAtLogin];

        // Set display mode button
        LGDefaults *defaults = [LGDefaults standardUserDefaults];
        LGApplicationDisplayStyle displayStyle = defaults.applicationDisplayStyle;

        _hideInDock.state = !(displayStyle & kLGDisplayStyleShowDock);
        _showInMenuButton.state = (displayStyle & kLGDisplayStyleShowMenu);
    }
}

- (NSString *)tabLabel
{
    return @"Install";
}

- (IBAction)changeDisplayMode:(NSButton *)sender
{
    NSApplication *app = [NSApplication sharedApplication];

    LGApplicationDisplayStyle newStyle = kLGDisplayStyleShowNone;

    if (!_hideInDock.state) {
        newStyle = kLGDisplayStyleShowDock;
    }

    if (_showInMenuButton.state) {
        newStyle = newStyle | kLGDisplayStyleShowMenu;
    }

    [[LGDefaults standardUserDefaults] setApplicationDisplayStyle:newStyle];

    if ([sender isEqualTo:_hideInDock]) {
        _restartRequiredLabel.hidden = !sender.state;
        if (!sender.state) {
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        }
    }

    if ([sender isEqualTo:_showInMenuButton]) {
        if ([app.delegate respondsToSelector:@selector(showStatusMenu:)]) {
            [app.delegate performSelector:@selector(showStatusMenu:) withObject:@(_showInMenuButton.state)];
        }
    }
}

- (IBAction)launchAtLogin:(NSButton *)sender
{
    if (![LGAutoPkgSchedule launchAtLogin:sender.state]) {
        sender.state = !sender.state;
    }
}

#pragma mark - Table View Delegate
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    if (!_toolManager.installStatusDidChangeHandler) {
        _toolManager.installStatusDidChangeHandler = ^(LGTool *tool, NSInteger index) {
            [tableView reloadData];
        };
    }
    return _toolManager.installedOrRequiredTools.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    __block LGToolStatusTableCellView *statusCell = nil;
    if ([tableColumn.identifier isEqualToString:@"statusCell"]) {
        statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

        LGTool *tool = _toolManager.installedOrRequiredTools[row];
        tool.progressDelegate = self.progressDelegate;

        statusCell.installButton.target = tool;
        statusCell.installButton.enabled = NO;
        statusCell.installButton.title = [@"Install " stringByAppendingString:[[tool class] name]];

        statusCell.textField.stringValue = [[[tool class] name] stringByAppendingString:@": checking status"];

        statusCell.imageView.hidden = YES;
        [statusCell.progressIndicator startAnimation:nil];

        [tool getInfo:^(LGToolInfo *info) {
            [statusCell.progressIndicator stopAnimation:nil];
            statusCell.imageView.hidden = NO;
            statusCell.imageView.image = info.statusImage;
            statusCell.textField.stringValue = info.statusString;

            statusCell.installButton.title = info.installButtonTitle;

            statusCell.installButton.action = info.targetAction;
            statusCell.installButton.enabled = info.installButtonEnabled;
        }];
    }
    return statusCell;
}

@end
