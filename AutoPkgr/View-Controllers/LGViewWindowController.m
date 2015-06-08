//
//  LGConfigWindowController.m
//  AutoPkgr
//
//  Created by Eldon on 6/6/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGViewWindowController.h"


@interface LGViewWindowController () <NSWindowDelegate>
@property (strong, nonatomic, readwrite) NSViewController *viewController;

@end

@implementation LGViewWindowController
- (instancetype)initPrivate
{
    return [self initWithWindowNibName:NSStringFromClass([LGViewWindowController class])];
}

- (instancetype)initWithViewController:(NSViewController *)viewController
{
    if (self = [self initPrivate]) {
        self->_viewController = viewController;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    /* We need to adjust the window size to accomidate the view.
     * Since the view is actually contained in an NSBox take the
     * current boxes frame size, and subtract the w/h from the
     * view controller's view size. This will give the difference
     * positive or negative that the window gets adjusted.
     * Then add that to the current window frame size
     */
    
    NSSize origSize = [_configBox.contentView frame].size;
    NSSize newSize = _viewController.view.frame.size;

    NSInteger height = (newSize.height - origSize.height);
    NSInteger width = (newSize.width - origSize.width);

    NSRect rect = NSMakeRect(0,
                             0,
                             self.window.frame.size.width + width,
                             self.window.frame.size.height + height);

    [self.window setFrame:rect display:YES];

    [self.configBox setContentView:_viewController.view];
    [self.configBox sizeToFit];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp endSheet:self.window];
}

- (IBAction)close:(id)sender
{
    [self.window close];
}

@end
