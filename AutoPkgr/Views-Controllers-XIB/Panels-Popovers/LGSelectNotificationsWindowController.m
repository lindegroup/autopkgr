//
//  LGSelectNotificationsWindow.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 12/7/15.
//  Copyright 2015-2016 The Linde Group, Inc.
//

#import "LGDefaults.h"
#import "LGSelectNotificationsWindowController.h"
#import "NSArray+mapped.h"

@interface LGSelectNotificationsWindowController ()
@property BOOL integrationUpdateState;
@property (weak) IBOutlet NSMatrix *enabledMatrix;
@property (weak) IBOutlet NSTextField *integrationDescription;

@end

@implementation LGSelectNotificationsWindowController {
    NSArray *_buttons;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    LGReportItems flags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    // All of the button tags have been setup in XIB with a corresponding LGReportItems flag
    // this allows us to enumerate & update flag values.
    _buttons = [[self.window.contentView subviews] mapObjectsUsingBlock:^id(id obj, NSUInteger idx) {
        if ([obj isMemberOfClass:[NSMatrix class]]) {
            [obj selectCellAtRow:!(flags & kLGReportItemsAll) column:0];
        }
        return ([obj isMemberOfClass:[NSButton class]] && [obj tag]) ? obj : nil;
    }];

    [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger idx, BOOL *_Nonnull stop) {
        button.state = (flags & button.tag);
    }];
    [self updateEnabled:flags];
}

- (IBAction)updateFlags:(id)sender
{
    LGReportItems flags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    NSInteger tag;
    BOOL state;

    if ([sender isKindOfClass:[NSMatrix class]]) {
        tag = kLGReportItemsAll;
        // The first row represents "Report All Items"
        state = ([sender selectedRow] == 0);
    }
    else {
        state = [sender state];
        tag = [sender tag];
    }

    if (state) {
        flags |= tag;
        [[LGDefaults standardUserDefaults] setReportedItemFlags:flags];
    }
    else {
        flags ^= tag;
        [[LGDefaults standardUserDefaults] setReportedItemFlags:flags];
    }
    [self updateEnabled:flags];
}

- (void)updateEnabled:(LGReportItems)flags
{
    self.integrationUpdateState = flags & kLGReportItemsIntegrationUpdates;
    self.integrationDescription.textColor = (flags & kLGReportItemsAll) ? [NSColor systemGrayColor] : [NSColor controlTextColor];

    [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger idx, BOOL *_Nonnull stop) {
        button.enabled = (button.tag == kLGReportItemsAll) || !(flags & kLGReportItemsAll);
    }];
}

- (IBAction)changeIntegrationUpdateState:(NSButton *)sender
{
    self.integrationUpdateState = [sender state];
}

@end
