//
//  LGGitIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/9/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGGitIntegrationView.h"
#import "NSOpenPanel+typeChooser.h"
#import "LGDefaults.h"
#import "NSTextField+safeStringValue.h"

@interface LGGitIntegrationView ()<NSTextFieldDelegate>

@property (weak) IBOutlet NSTextField *githPathTF;

@end

@implementation LGGitIntegrationView

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib {
    _githPathTF.safe_stringValue = [[LGDefaults standardUserDefaults] gitPath];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if ([obj.object isEqualTo:_githPathTF]) {
        [self setGitPath:_githPathTF];
    }
}

- (IBAction)setGitPath:(id)sender
{
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    if ([sender isKindOfClass:[NSButton class]]) {
        [NSOpenPanel executableChooser_WithStartingPath:defaults.gitPath reply:^(NSString *selectedExecutable) {
            if (selectedExecutable) {
                _githPathTF.stringValue = selectedExecutable;
                _githPathTF.textColor = [NSColor blackColor];
                defaults.gitPath = selectedExecutable;
            }
        }];
    } else if ([sender isEqualTo:_githPathTF]){
        NSString *path = [sender stringValue];

        BOOL (^validExecutable)(NSTextField *) = ^BOOL (NSTextField *textField) {
            BOOL success = NO;
            BOOL isDir;
            if (([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir) &&
                ([[NSFileManager defaultManager] isExecutableFileAtPath:path])) {
                [sender setTextColor:[NSColor blackColor]];
                success =  YES;
            } else {
                [sender setTextColor:[NSColor redColor]];
            }
            return success;
        };

        if(validExecutable(sender)){
            defaults.gitPath = path.stringByExpandingTildeInPath;
        }
    }
}
@end
