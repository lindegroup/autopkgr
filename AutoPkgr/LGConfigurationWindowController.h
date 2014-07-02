//
//  LGConfigurationWindowController.h
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LGConfigurationWindowController : NSWindowController <NSTokenFieldDelegate>

// Text/token fields
@property (weak) IBOutlet NSTokenField *smtpTo;
@property (weak) IBOutlet NSTextField *smtpServer;
@property (weak) IBOutlet NSTextField *smtpUsername;
@property (weak) IBOutlet NSSecureTextField *smtpPassword;
@property (weak) IBOutlet NSTextField *smtpPort;

// Check boxes
@property (weak) IBOutlet NSButton *smtpAuthenticationEnabledButton;
@property (weak) IBOutlet NSButton *smtpTLSEnabledButton;
@property (weak) IBOutlet NSButton *warnBeforeQuittingButton;

// Actions
- (IBAction)sendTestEmail:(id)sender;
- (IBAction)saveAndClose:(id)sender;

@end
