//
//  LGMunkiIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/7/15.
//  Copyright 2015 Eldon Ahrold
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
//  limitations under the License.
//


#import "LGMunkiIntegrationView.h"
#import "LGAutoPkgr.h"

#import "NSOpenPanel+folderChooser.h"

@interface LGMunkiIntegrationView ()

@property (weak) IBOutlet NSTextField *localMunkiRepo;
@property (weak) IBOutlet NSButton *openLocalMunkiRepoFolderButton;

- (IBAction)chooseLocalMunkiRepo:(id)sender;
- (IBAction)openLocalMunkiRepoFolder:(id)sender;

@end

@implementation LGMunkiIntegrationView

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib {
    BOOL isDir;
    NSString *munkiRepo = [[LGDefaults standardUserDefaults] munkiRepo];

    if ([[NSFileManager defaultManager] fileExistsAtPath:munkiRepo isDirectory:&isDir] && isDir) {
        _openLocalMunkiRepoFolderButton.enabled = YES;
        _localMunkiRepo.stringValue = munkiRepo;
    } else {
        _openLocalMunkiRepoFolderButton.enabled = NO;
    }
}

- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    DevLog(@"Showing dialog for selecting Munki repo location.");

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    NSString *path = [[LGDefaults standardUserDefaults] munkiRepo] ?: @"/Users/Shared";

    // Display the dialog. If the "Choose" button was (This is a custom category)
    [NSOpenPanel folderChooser_WithStartingPath:path reply:^(NSString *selectedFolder) {
        if (selectedFolder) {
            DevLog(@"%@ selected for Munki repo location.", selectedFolder);
            [_localMunkiRepo setStringValue:selectedFolder];
            [_openLocalMunkiRepoFolderButton setEnabled:YES];
            [LGDefaults standardUserDefaults].munkiRepo = selectedFolder;
        }
    }];
}

- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    DLog(@"Opening Munki repo folder...");

    NSString *munkiRepoFolder = [[LGDefaults standardUserDefaults] munkiRepo];
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:munkiRepoFolder isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:munkiRepoFolder];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", munkiRepoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, munkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:nil
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}
@end
