//
//  LGGitIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/9/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGGitIntegrationView.h"
#import "LGGitIntegration.h"
#import "LGDefaults.h"

#import "NSString+cleaned.h"
#import "NSOpenPanel+typeChooser.h"
#import "NSTextField+safeStringValue.h"

@interface LGGitIntegrationView () <NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *githPathTF;
@property (weak) IBOutlet NSButton *installButton;
@property (weak) IBOutlet NSTextField *progressMessageTF;

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

    BOOL officialGitInstalled = [[(LGGitIntegration *)self.integration class] officialGitInstalled ];
    _progressMessageTF.hidden = officialGitInstalled;
    _installButton.hidden = officialGitInstalled;
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

- (IBAction)installOfficialGit:(id)sender {
    [self.progressSpinner startAnimation:self];
    self.progressMessageTF.hidden = NO;

    [self.integration install:^(NSString *message, double progress) {
        self.progressMessageTF.safe_stringValue = [message truncateToLength:30];
    } reply:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.progressSpinner stopAnimation:self];
            self.installButton.hidden = (error == nil);

            self.progressMessageTF.hidden = YES;
            self.githPathTF.safe_stringValue = [[LGDefaults standardUserDefaults] gitPath];
        });
    }];
}

@end
