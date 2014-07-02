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

// Checkboxes
@property (weak) IBOutlet NSButton *smtpAuthenticationEnabledButton;
@property (weak) IBOutlet NSButton *smtpTLSEnabledButton;
@property (weak) IBOutlet NSButton *warnBeforeQuittingButton;

// Buttons
@property (weak) IBOutlet NSButton *autoPkgCacheFolderButton;
@property (weak) IBOutlet NSButton *autoPkgRecipeReposFolderButton;
@property (weak) IBOutlet NSButton *localMunkiRepoFolderButton;

// Labels
@property (weak) IBOutlet NSTextField *gitStatusLabel;
@property (weak) IBOutlet NSTextField *autoPkgStatusLabel;

// Status icons
@property (weak) IBOutlet NSImageView *gitStatusIcon;
@property (weak) IBOutlet NSImageView *autoPkgStatusIcon;

// Matrices
@property (weak) IBOutlet NSMatrix *scheduleMatrix;

// IBActions
- (IBAction)sendTestEmail:(id)sender;
- (IBAction)saveAndClose:(id)sender;
- (IBAction)installGit:(id)sender;
- (IBAction)installAutoPkg:(id)sender;
- (IBAction)openAutoPkgCacheFolder:(id)sender;
- (IBAction)openAutoPkgRecipeReposFolder:(id)sender;
- (IBAction)openLocalMunkiRepoFolder:(id)sender;

- (void)runCommandAsRoot:(NSString *)runDirectory command:(NSString *)command;
- (void)downloadAndInstallAutoPkg;

@end
