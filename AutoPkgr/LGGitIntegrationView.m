//
//  LGGitIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/9/15.
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

#import "LGGitIntegrationView.h"
#import "LGGitIntegration.h"
#import "LGDefaults.h"

#import "NSString+cleaned.h"
#import "NSOpenPanel+typeChooser.h"
#import "NSTextField+safeStringValue.h"

@interface LGGitIntegrationView () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *githPathTF;

@end

@implementation LGGitIntegrationView

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    _githPathTF.safe_stringValue = [[LGDefaults standardUserDefaults] gitPath];
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    if ([obj.object isEqualTo:_githPathTF]) {
        [self setGitPath:_githPathTF];
    }
}

- (IBAction)setGitPath:(id)sender
{
    LGDefaults *defaults = [LGDefaults standardUserDefaults];
    NSString *initialGitPath = defaults.gitPath;

    BOOL (^validExecutable)(NSString * path, NSTextField *) = ^BOOL(NSString *path, NSTextField *textField) {
        BOOL success = NO;
        BOOL isDir;
        if (([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir) &&
            ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) &&
            [path.lastPathComponent isEqualToString:@"git"]) {
            [textField setTextColor:[NSColor blackColor]];
            success =  YES;
            if (![initialGitPath isEqualToString:path]) {
                /* Here trigger the refresh, but also call post a notification
                 * that the status changed so the integration's manager updates
                 * it's status change handler.
                 */
                 [self.integration refresh];
                [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationIntegrationStatusDidChange object:self.integration];
            }
        } else {
            [textField setTextColor:[NSColor redColor]];
        }
        return success;
    };

    if ([sender isKindOfClass:[NSButton class]]) {
        [NSOpenPanel executableChooser_WithStartingPath:defaults.gitPath reply:^(NSString *selectedExecutable) {
            if(validExecutable(selectedExecutable, nil)){
                _githPathTF.stringValue = selectedExecutable;
                defaults.gitPath = selectedExecutable.stringByExpandingTildeInPath;
            }
        }];

    } else if ([sender isEqualTo:_githPathTF]) {
        NSString *path = [sender stringValue];

        if (validExecutable(path, sender)) {
            defaults.gitPath = path.stringByExpandingTildeInPath;
        }
    }
}

@end
