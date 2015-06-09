//
//  LGConfigWindowController.m
//  AutoPkgr
//
//  Created by Eldon on 6/6/15.
//  Copyright (c) 2015 Eldon Ahrold.
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
     * current box's frame size, and subtract the w/h from the
     * view controller's view size. This will give the difference
     * positive or negative that the window gets adjusted.
     * Then add that to the current window frame size
     */
    
    NSSize origSize = [_configBox.contentView frame].size;
    NSSize newSize = _viewController.view.frame.size;

    NSInteger height = (newSize.height - origSize.height);
    NSInteger width = (newSize.width - origSize.width);

    NSSize minSize = NSMakeSize(self.window.frame.size.width + width,
                                self.window.frame.size.height + height);

    NSRect rect = NSMakeRect(0,
                             0,
                             minSize.width,
                             minSize.height);

    [self.window setFrame:rect display:YES];
    [self.window setMinSize:minSize];

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
