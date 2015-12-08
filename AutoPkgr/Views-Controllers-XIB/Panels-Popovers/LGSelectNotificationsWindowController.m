//
//  LGSelectNotificationsWindow.m
//  AutoPkgr
//
//  Created by Eldon on 12/7/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGSelectNotificationsWindowController.h"
#import "LGDefaults.h"
#import "NSArray+mapped.h"

@interface LGSelectNotificationsWindowController ()
@property BOOL integrationUpdateState;
@end

@implementation LGSelectNotificationsWindowController {
    NSArray *_buttons;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    // All of the button tags have been setup in XIB with a cooresponding LGReportItems flag
    // this allows us to enumerate & update flag values.
    _buttons = [[self.window.contentView subviews] mapObjectsUsingBlock:^id(NSButton *obj, NSUInteger idx) {
        return ([obj isMemberOfClass:[NSButton class]] && obj.tag) ? obj : nil;
    }];


    LGReportItems flags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger idx, BOOL * _Nonnull stop) {
        button.state = (flags & button.tag);
    }];
    [self updateEnabled:flags];
}

- (IBAction)updateFlags:(NSButton *)sender {
    LGReportItems flags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    if (sender.state) {
        flags |= sender.tag;
        [[LGDefaults standardUserDefaults] setReportedItemFlags:flags];
    } else {
        flags ^= sender.tag;
        [[LGDefaults standardUserDefaults] setReportedItemFlags:flags];
    }
    [self updateEnabled:flags];
}

- (void)updateEnabled:(LGReportItems)flags {
    self.integrationUpdateState = flags & kLGReportItemsIntegrationUpdates;
    [_buttons enumerateObjectsUsingBlock:^(NSButton *button, NSUInteger idx, BOOL * _Nonnull stop) {
        button.enabled = (button.tag == kLGReportItemsAll) || !(flags & kLGReportItemsAll);
    }];
}

- (IBAction)changeIntegrationUpdateState:(NSButton *)sender {
    self.integrationUpdateState = [sender state];
}

@end
