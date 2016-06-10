//
//  LGJSSImporterIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 9/25/14.
//  Copyright 2014-2016 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGJSSImporterIntegrationView.h"

#import "LGAutoPkgTask.h"
#import "LGAutopkgr.h"
#import "LGHTTPRequest.h"
#import "LGHostInfo.h"
#import "LGInstaller.h"
#import "LGJSSDistributionPoint.h"
#import "LGJSSDistributionPointsPrefPanel.h"
#import "LGJSSImporterIntegration.h"
#import "LGServerCredentials.h"
#import "LGTableView.h"
#import "LGTestPort.h"

#import "NSTableView+Resizing.h"
#import "NSTextField+changeHandle.h"

@interface LGJSSImporterIntegrationView () <NSTextFieldDelegate>
@property (strong) IBOutlet LGTableView *jssDistributionPointTableView;
@property (weak) IBOutlet NSTextField *jssURLTF;
@property (weak) IBOutlet NSTextField *jssAPIUsernameTF;
@property (weak) IBOutlet NSTextField *jssAPIPasswordTF;
@property (weak) IBOutlet NSButton *jssReloadServerBT;
@property (weak) IBOutlet NSProgressIndicator *jssStatusSpinner;
@property (weak) IBOutlet NSImageView *jssStatusLight;

@property (weak) IBOutlet NSButton *jssEditDistPointBT;
@property (weak) IBOutlet NSButton *jssRemoveDistPointBT;

@property (weak) IBOutlet NSButton *jssVerifySSLBT;

@property (weak) NSWindow *modalWindow;

- (IBAction)addDistributionPoint:(id)sender;
- (IBAction)removeDistributionPoint:(id)sender;
- (IBAction)editDistributionPoint:(id)sender;

@end

#pragma mark - LGJSSImporterIntegrationView
@implementation LGJSSImporterIntegrationView {
    NSArray *_distributionPoints;
    LGTestPort *_portTester;
    LGJSSDistributionPointsPrefPanel *_preferencePanel;
    BOOL _serverReachable;
}

- (void)awakeFromNib
{
    LGJSSImporterDefaults *defaults = [LGJSSImporterDefaults new];
    // Disable the Add / Remove buttons until a row is selected.
    [_jssEditDistPointBT setEnabled:NO];
    [_jssRemoveDistPointBT setEnabled:NO];

    // .safeStringValue is a NSTextField category that you can pass a nil value into.
    _jssAPIUsernameTF.safe_stringValue = defaults.JSSAPIUsername;
    _jssAPIPasswordTF.safe_stringValue = defaults.JSSAPIPassword;
    _jssURLTF.safe_stringValue = defaults.JSSURL;

    _jssReloadServerBT.action = @selector(getDistributionPoints:);
    _jssReloadServerBT.title = @"Connect";

    __weak typeof(self) weakSelf = self;
    [self.jssAPIPasswordTF textChanged:^(NSString *newVal) {
        defaults.JSSAPIPassword = newVal;
    }];

    [_jssAPIUsernameTF textChanged:^(NSString *newVal) {
        defaults.JSSAPIUsername = newVal;
    }];

    [[self.jssURLTF textChanged:^(NSString *newVal) {
        defaults.JSSURL = newVal;
    }] editingEnded:^(NSTextField *jssURLTF) {
        [self startStatusUpdate];
        LGTestPort *tester = [[LGTestPort alloc] init];
        [tester testServerURL:jssURLTF.stringValue
                        reply:^(BOOL reachable, NSString *redirectedURL) {
                            if (redirectedURL) {
                                [weakSelf warnOfRedirection:redirectedURL];
                            }
                            [weakSelf stopStatusUpdate:nil];
                        }];
    }];

    _jssVerifySSLBT.state = defaults.JSSVerifySSL;
    [_jssDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)verifySSL:(NSButton *)sender
{
    [[LGJSSImporterDefaults new] setJSSVerifySSL:_jssVerifySSLBT.state];
}

- (IBAction)getDistributionPoints:(id)sender
{
    [sender setEnabled:NO];
    [LGJSSDistributionPoint getFromRemote:^(NSArray<LGJSSDistributionPoint *> *distPoints, NSError *error) {
        [sender setEnabled:YES];
        [self stopStatusUpdate:error];
        if (error) {
            [NSApp presentError:error];
        }
        else {
            [_jssStatusLight setImage:[NSImage LGStatusAvailable]];
            for (LGJSSDistributionPoint *dp in distPoints) {
                if ((dp.password = [self promptForSharePassword:dp.name]) != nil) {
                    [dp save];
                }
            }
            [self.jssDistributionPointTableView reloadData];
        }
    }];
}

#pragma mark - Progress
- (void)startStatusUpdate
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jssStatusLight setHidden:YES];
        [_jssStatusSpinner setHidden:NO];
        [_jssStatusSpinner startAnimation:self];
    }];
}

- (void)stopStatusUpdate:(NSError *)error
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jssStatusLight setHidden:NO];
        [_jssStatusSpinner setHidden:YES];
        [_jssStatusSpinner stopAnimation:self];
        if (error) {
            NSLog(@"JSS Error: [%ld] %@", error.code, error.localizedDescription);
            [self.integration.progressDelegate stopProgress:error];
            [_jssStatusLight setImage:[NSImage LGStatusUnavailable]];
        }
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    _distributionPoints = [LGJSSDistributionPoint enabledDistributionPoints];
    return _distributionPoints.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ((row + 1) == tableView.numberOfRows) {
        [tableView resized_HeightToFit];
    }
    return [_distributionPoints[row] description];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    LGJSSDistributionPoint *distributionPoint = _distributionPoints[row];

    // Local mounts have slightly different implementation so we need to hijack this a little bit.
    NSString *identifier = nil;
    if (distributionPoint.type == kLGJSSTypeLocal) {
        if ([tableColumn.identifier isEqualToString:@"URL"]) {
            identifier = kLGJSSDistPointMountPointKey;
        }
        else if ([tableColumn.identifier isEqualToString:@"share_name"]) {
            identifier = kLGJSSDistPointSharePointKey;
        }
    }
    else {
        identifier = tableColumn.identifier;
    }

    if (identifier && [distributionPoint respondsToSelector:NSSelectorFromString(identifier)]) {
        [distributionPoint setValue:object forKey:identifier];
        [distributionPoint save];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [_jssDistributionPointTableView selectedRow];
    // If nothing in the table is selected, the row value is -1.
    [_jssRemoveDistPointBT setEnabled:(row > -1)];
    [_jssEditDistPointBT setEnabled:(row > -1) && [_distributionPoints[row] isEditable]];
}

#pragma mark - Alerts
- (void)confirmDisableSSLVerify
{
    NSString *alertTitle = NSLocalizedStringFromTable(@"Unable to verify the SSL certificate.",
                                                      @"LocalizableJSSImporter",
                                                      @"message when JSS cannot be verified");

    NSString *defaultButton = NSLocalizedStringFromTable(@"Keep SSL Verification",
                                                         @"LocalizableJSSImporter",
                                                         @"button title for alert when ssl verification should remain enabled.");

    NSString *altButton = NSLocalizedStringFromTable(@"Disable SSL Verification",
                                                     @"LocalizableJSSImporter",
                                                     @"button title to disable ssl verificaiton");

    NSString *infoText = NSLocalizedStringFromTable(@"This is possibly due to the certificate being self signed. Choosing \"Disable SSL Verification\" may be required for JSSImporter to function properly. If you are sure the JSS is using a trusted certificate signed by a public Certificate Authority, keep SSL verification enabled.",
                                                    @"LocalizableJSSImporter",
                                                    nil);

    NSAlert *alert = [NSAlert alertWithMessageText:alertTitle defaultButton:defaultButton alternateButton:altButton otherButton:nil informativeTextWithFormat:@"%@", infoText];

    [[LGJSSImporterDefaults new] setJSSVerifySSL:([alert runModal] == NSModalResponseOK)];
}

- (NSString *)promptForSharePassword:(NSString *)shareName
{
    NSLog(@"Prompting for password for distribution point: %@", shareName);
    NSString *password;
    NSString *messageText = NSLocalizedStringFromTable(@"Distribution Point Password Required",
                                                       @"LocalizableJSSImporter",
                                                       nil);

    NSString *infoText = NSLocalizedStringFromTable(@"Please enter read/write password for the \"%@\" distribution point. If you intend to configure manually just click \"Cancel\".", @"LocalizableJSSImporter", nil);

    NSAlert *alert = [NSAlert alertWithMessageText:messageText
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:infoText, shareName];

    NSSecureTextField *input = [[NSSecureTextField alloc] init];
    [input setLineBreakMode:NSLineBreakByClipping];
    [input setFrame:NSMakeRect(0, 0, 300, 24)];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        password = [input stringValue];
        if (!password || [password isEqualToString:@""]) {
            return [self promptForSharePassword:shareName];
        }
    }
    return password;
}

- (void)warnOfRedirection:(NSString *)redirectURL
{
    NSAlert *alert = [[NSAlert alloc] init];
    NSString *title = NSLocalizedStringFromTable(@"The server redirected the requested URL.",
                                                 @"LocalizableJSSImporter",
                                                 @"alert title when server sends a redirect for JSS");

    NSString *informativeText = NSLocalizedStringFromTable(@"The server redirected the request to\n\n%@\n\nYou should consider using this for the JSS url.",
                                                           @"LocalizableJSSImporter",
                                                           @"informativeText when server sends a redirect.");
    alert.messageText = title;
    alert.informativeText = quick_formatString(informativeText, redirectURL);
    [alert addButtonWithTitle:@"Use suggested URL"];
    [alert addButtonWithTitle:@"Ignore"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        _jssURLTF.stringValue = redirectURL;
        [[LGJSSImporterDefaults new] setJSSURL:redirectURL];
    }
}

#pragma mark - JSS Distribution Point Preference Panel
- (void)addDistributionPoint:(id)sender
{
    if (!_preferencePanel) {
        _preferencePanel = [[LGJSSDistributionPointsPrefPanel alloc] init];
    }

    [NSApp beginSheet:_preferencePanel.window
        modalForWindow:_modalWindow
         modalDelegate:self
        didEndSelector:@selector(didClosePreferencePanel)
           contextInfo:nil];
}

- (void)removeDistributionPoint:(id)sender
{
    LGJSSDistributionPoint *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    }
    else {
        NSInteger row = _jssDistributionPointTableView.selectedRow;
        if (row > -1) {
            distPoint = _distributionPoints[row];
        }
    }
    [distPoint remove];
    [_jssDistributionPointTableView reloadData];
}

- (void)editDistributionPoint:(id)sender
{
    LGJSSDistributionPoint *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    }
    else {
        NSInteger row = _jssDistributionPointTableView.selectedRow;
        if (0 <= row) {
            distPoint = _distributionPoints[row];
        }
    }

    if (distPoint) {
        if (!_preferencePanel) {
            _preferencePanel = [[LGJSSDistributionPointsPrefPanel alloc] initWithDistPoint:distPoint];
        }

        [NSApp beginSheet:_preferencePanel.window
            modalForWindow:_modalWindow
             modalDelegate:self
            didEndSelector:@selector(didClosePreferencePanel)
               contextInfo:nil];
    }
}

#pragma mark - Panel didEnd Selectors
- (void)didClosePreferencePanel
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_preferencePanel.window close];
        [_jssDistributionPointTableView reloadData];
        _preferencePanel = nil;
    });
}
@end
