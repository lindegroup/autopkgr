//
//  LGWindowController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 12/7/15.
//  Copyright 2015 The Linde Group, Inc.
//

#import "LGWindowController.h"

@interface LGWindowController ()

@end

@implementation LGWindowController {
    void (^_controllerCloseHandle)(LGWindowController *);
}

- (instancetype)init {
    if (!(self = [super initWithWindowNibName:NSStringFromClass([self class])])) {
        self = [super initWithWindowNibName:NSStringFromClass([LGWindowController class])];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)open:(windowCloseHandle)closed {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(willClose:)
                                                 name:NSWindowWillCloseNotification
                                               object:self.window];
    _controllerCloseHandle = closed;
    [self showWindow:nil];

}

- (void)openSheetOnWindow:(NSWindow *)window complete:(windowCloseHandle)complete
{
    _controllerCloseHandle = complete;
    [NSApp beginSheet:self.window
       modalForWindow:window
        modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo:nil];
}

- (IBAction)close:(id)sender {
    [self close];
}

- (void)willClose:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowWillCloseNotification
                                                  object:notification.object];
    if (_controllerCloseHandle) {
        _controllerCloseHandle(self);
    }
}

- (IBAction)closeSheet:(id)sender
{
    if ([self.window isKindOfClass:[NSWindow class]]) {
        if([self.window makeFirstResponder:nil]){
            [self.window orderOut:nil];
            [NSApp endSheet:self.window];
        }
    }
}

- (void)sheetDidEnd:(NSWindow *)sheet
         returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo;
{
    if (_controllerCloseHandle) {
        _controllerCloseHandle(self);
    }
}

@end
