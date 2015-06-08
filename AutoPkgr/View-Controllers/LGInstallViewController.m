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
    __block NSArray *currentTools = _toolManager.installedOrRequiredTools;

    if (!_toolManager.installStatusDidChangeHandler) {
        _toolManager.installStatusDidChangeHandler = ^(LGToolManager *aManager, LGTool *tool) {
            [tableView beginUpdates];

            if ([aManager.requiredTools containsObject:tool]) {
                /* If the tool is required, we don't need to add/remove any rows
                 * simply reload the data for the row */
                NSInteger index = [aManager.installedOrRequiredTools indexOfObject:tool];
                NSIndexSet *idxSet = [NSIndexSet indexSetWithIndex:index];

                [tableView reloadDataForRowIndexes:idxSet
                                     columnIndexes:[NSIndexSet
                                                    indexSetWithIndexesInRange:
                                                    NSMakeRange(0, tableView.numberOfColumns)]];

            } else if (tool.isInstalled) {
                /* If the tool is now installed, check that it was NOT previously
                 * listed as installed by checking the `currentTools` array
                 * and add in a row to the table if not found */
                if ([currentTools indexOfObject:tool] == NSNotFound) {
                    // NSNotFound means that the tool was previously not installed.
                    NSInteger index = [aManager.installedOrRequiredTools indexOfObject:tool];
                    if (index != NSNotFound) {
                        NSIndexSet *idxSet = [NSIndexSet indexSetWithIndex:index];
                        [tableView insertRowsAtIndexes:idxSet  withAnimation:NSTableViewAnimationEffectFade];

                        [tableView reloadDataForRowIndexes:idxSet
                                             columnIndexes:[NSIndexSet
                                                            indexSetWithIndexesInRange:
                                                            NSMakeRange(0, tableView.numberOfColumns)]];
                        // Reset the currentTools
                        currentTools = aManager.installedOrRequiredTools;
                    }
                }
            } else {
                /* Otherwise it's no longer installed and we want to remove
                 * the row from the table that's represended by the index of
                 * of the integration in the 'currentTools' array */
                NSInteger index = [currentTools indexOfObject:tool];
                if (index != NSNotFound) {
                    [tableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:index]
                                     withAnimation:NSTableViewAnimationEffectFade];

                    // Reset the currentTools
                    currentTools = aManager.installedOrRequiredTools;
                }
            }
            [tableView endUpdates];
        };
    }

    return _toolManager.installedOrRequiredTools.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    __block LGToolStatusTableCellView *statusCell = nil;
    if ([tableColumn.identifier isEqualToString:@"statusCell"]) {

        LGTool *tool = _toolManager.installedOrRequiredTools[row];
        tool.progressDelegate = self.progressDelegate;

        statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];
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

            statusCell.installButton.action = info.installButtonTargetAction;
            statusCell.installButton.enabled = info.installButtonEnabled;
        }];
    }
    return statusCell;
}

@end
