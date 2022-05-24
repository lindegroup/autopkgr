//
//  LGJamfUploaderIntegrationView.m
//  AutoPkgr
//
//  Copyright 2022 The Linde Group.
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

#import "LGJamfUploaderIntegrationView.h"

#import "LGAutoPkgTask.h"
#import "LGAutopkgr.h"
#import "LGHTTPRequest.h"
#import "LGHostInfo.h"
#import "LGInstaller.h"
#import "LGJamfDistributionPoint.h"
#import "LGJamfDistributionPointsPrefPanel.h"
#import "LGJamfUploaderIntegration.h"
#import "LGServerCredentials.h"
#import "LGTableView.h"
#import "LGTestPort.h"

#import "NSTableView+Resizing.h"
#import "NSTextField+changeHandle.h"

@interface LGJamfUploaderIntegrationView () <NSTextFieldDelegate>
@property (strong) IBOutlet LGTableView *jamfDistributionPointTableView;
@property (weak) IBOutlet NSTextField *jamfURLTF;
@property (weak) IBOutlet NSTextField *jamfAPIUsernameTF;
@property (weak) IBOutlet NSTextField *jamfAPIPasswordTF;
@property (weak) IBOutlet NSButton *jamfReloadServerBT;
@property (weak) IBOutlet NSProgressIndicator *jamfStatusSpinner;
@property (weak) IBOutlet NSImageView *jamfStatusLight;

@property (weak) IBOutlet NSButton *jamfEditDistPointBT;
@property (weak) IBOutlet NSButton *jamfRemoveDistPointBT;

@property (weak) IBOutlet NSButton *jamfVerifySSLBT;

@property (weak) NSWindow *modalWindow;

- (IBAction)addDistributionPoint:(id)sender;
- (IBAction)removeDistributionPoint:(id)sender;
- (IBAction)editDistributionPoint:(id)sender;

@end

#pragma mark - LGJamfUploaderIntegrationView
@implementation LGJamfUploaderIntegrationView {
    NSArray *_distributionPoints;
    LGTestPort *_portTester;
    LGJamfDistributionPointsPrefPanel *_preferencePanel;
    BOOL _serverReachable;
}

- (void)awakeFromNib
{
    LGJamfUploaderDefaults *defaults = [LGJamfUploaderDefaults new];
    // Disable the Add / Remove buttons until a row is selected.
    [_jamfEditDistPointBT setEnabled:NO];
    [_jamfRemoveDistPointBT setEnabled:NO];

    // .safeStringValue is a NSTextField category that you can pass a nil value into.
    _jamfAPIUsernameTF.safe_stringValue = defaults.JSSAPIUsername;
    _jamfAPIPasswordTF.safe_stringValue = defaults.JSSAPIPassword;
    _jamfURLTF.safe_stringValue = defaults.JSSURL;

    _jamfReloadServerBT.action = @selector(getDistributionPoints:);
    _jamfReloadServerBT.title = @"Connect";

    __weak typeof(self) weakSelf = self;
    [self.jamfAPIPasswordTF textChanged:^(NSString *newVal) {
        defaults.JSSAPIPassword = newVal;
    }];

    [_jamfAPIUsernameTF textChanged:^(NSString *newVal) {
        defaults.JSSAPIUsername = newVal;
    }];

    [[self.jamfURLTF textChanged:^(NSString *newVal) {
        defaults.JSSURL = newVal;
    }] editingEnded:^(NSTextField *jamfURLTF) {
        [self startStatusUpdate];
        LGTestPort *tester = [[LGTestPort alloc] init];
        [tester testServerURL:jamfURLTF.stringValue
                        reply:^(BOOL reachable, NSString *redirectedURL) {
                            if (redirectedURL) {
                                [weakSelf warnOfRedirection:redirectedURL];
                            }
                            [weakSelf stopStatusUpdate:nil];
                        }];
    }];

    _jamfVerifySSLBT.state = defaults.JSSVerifySSL;
    [_jamfDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)verifySSL:(NSButton *)sender
{
    [[LGJamfUploaderDefaults new] setJSSVerifySSL:_jamfVerifySSLBT.state];
}

- (IBAction)getDistributionPoints:(id)sender
{
    [sender setEnabled:NO];
    [LGJamfDistributionPoint getFromRemote:^(NSArray<LGJamfDistributionPoint *> *distPoints, NSError *error) {
        [sender setEnabled:YES];
        [self stopStatusUpdate:error];
        if (error) {
            [NSApp presentError:error];
        }
        else {
            [_jamfStatusLight setImage:[NSImage LGStatusAvailable]];
            for (LGJamfDistributionPoint *dp in distPoints) {
                if ((dp.password = [self promptForSharePassword:dp.name]) != nil) {
                    [dp save];
                }
            }
            [self.jamfDistributionPointTableView reloadData];
        }
    }];
}

#pragma mark - Progress
- (void)startStatusUpdate
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jamfStatusLight setHidden:YES];
        [_jamfStatusSpinner setHidden:NO];
        [_jamfStatusSpinner startAnimation:self];
    }];
}

- (void)stopStatusUpdate:(NSError *)error
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jamfStatusLight setHidden:NO];
        [_jamfStatusSpinner setHidden:YES];
        [_jamfStatusSpinner stopAnimation:self];
        if (error) {
            NSLog(@"JAMF Error: [%ld] %@", error.code, error.localizedDescription);
            [self.integration.progressDelegate stopProgress:error];
            [_jamfStatusLight setImage:[NSImage LGStatusUnavailable]];
        }
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    _distributionPoints = [LGJamfDistributionPoint enabledDistributionPoints];
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

    LGJamfDistributionPoint *distributionPoint = _distributionPoints[row];

    // Local mounts have slightly different implementation so we need to hijack this a little bit.
    NSString *identifier = nil;
    if (distributionPoint.type == kLGJamfTypeLocal) {
        if ([tableColumn.identifier isEqualToString:@"URL"]) {
            identifier = kLGJamfDistPointMountPointKey;
        }
        else if ([tableColumn.identifier isEqualToString:@"share_name"]) {
            identifier = kLGJamfDistPointSharePointKey;
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
    NSInteger row = [_jamfDistributionPointTableView selectedRow];
    // If nothing in the table is selected, the row value is -1.
    [_jamfRemoveDistPointBT setEnabled:(row > -1)];
    [_jamfEditDistPointBT setEnabled:(row > -1) && [_distributionPoints[row] isEditable]];
}

#pragma mark - Alerts
- (void)confirmDisableSSLVerify
{
    NSString *alertTitle = NSLocalizedStringFromTable(@"Unable to verify the SSL certificate.",
                                                      @"LocalizableJamfUploader",
                                                      @"message when JAMF cannot be verified");

    NSString *defaultButton = NSLocalizedStringFromTable(@"Keep SSL Verification",
                                                         @"LocalizableJamfUploader",
                                                         @"button title for alert when ssl verification should remain enabled.");

    NSString *altButton = NSLocalizedStringFromTable(@"Disable SSL Verification",
                                                     @"LocalizableJamfUploader",
                                                     @"button title to disable ssl verificaiton");

    NSString *infoText = NSLocalizedStringFromTable(@"This is possibly due to the certificate being self signed. Choosing \"Disable SSL Verification\" may be required for JamfUploader to function properly. If you are sure the JAMF is using a trusted certificate signed by a public Certificate Authority, keep SSL verification enabled.",
                                                    @"LocalizableJamfUploader",
                                                    nil);

    NSAlert *alert = [NSAlert alertWithMessageText:alertTitle defaultButton:defaultButton alternateButton:altButton otherButton:nil informativeTextWithFormat:@"%@", infoText];

    [[LGJamfUploaderDefaults new] setJSSVerifySSL:([alert runModal] == NSModalResponseOK)];
}

- (NSString *)promptForSharePassword:(NSString *)shareName
{
    NSLog(@"Prompting for password for distribution point: %@", shareName);
    NSString *password;
    NSString *messageText = NSLocalizedStringFromTable(@"Distribution Point Password Required",
                                                       @"LocalizableJamfUploader",
                                                       nil);

    NSString *infoText = NSLocalizedStringFromTable(@"Please enter read/write password for the \"%@\" distribution point. If you intend to configure manually just click \"Cancel\".", @"LocalizableJamfUploader", nil);

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
                                                 @"LocalizableJamfUploader",
                                                 @"alert title when server sends a redirect for JAMF");

    NSString *informativeText = NSLocalizedStringFromTable(@"The server redirected the request to\n\n%@\n\nYou should consider using this for the JAMF url.",
                                                           @"LocalizableJamfUploader",
                                                           @"informativeText when server sends a redirect.");
    alert.messageText = title;
    alert.informativeText = quick_formatString(informativeText, redirectURL);
    [alert addButtonWithTitle:@"Use suggested URL"];
    [alert addButtonWithTitle:@"Ignore"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        _jamfURLTF.stringValue = redirectURL;
        [[LGJamfUploaderDefaults new] setJSSURL:redirectURL];
    }
}

#pragma mark - JAMF Distribution Point Preference Panel
- (void)addDistributionPoint:(id)sender
{
    if (!_preferencePanel) {
        _preferencePanel = [[LGJamfDistributionPointsPrefPanel alloc] init];
    }

    [NSApp beginSheet:_preferencePanel.window
        modalForWindow:_modalWindow
         modalDelegate:self
        didEndSelector:@selector(didClosePreferencePanel)
           contextInfo:nil];
}

- (void)removeDistributionPoint:(id)sender
{
    LGJamfDistributionPoint *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    }
    else {
        NSInteger row = _jamfDistributionPointTableView.selectedRow;
        if (row > -1) {
            distPoint = _distributionPoints[row];
        }
    }
    [distPoint remove];
    [_jamfDistributionPointTableView reloadData];
}

- (void)editDistributionPoint:(id)sender
{
    LGJamfDistributionPoint *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    }
    else {
        NSInteger row = _jamfDistributionPointTableView.selectedRow;
        if (0 <= row) {
            distPoint = _distributionPoints[row];
        }
    }

    if (distPoint) {
        if (!_preferencePanel) {
            _preferencePanel = [[LGJamfDistributionPointsPrefPanel alloc] initWithDistPoint:distPoint];
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
        [_jamfDistributionPointTableView reloadData];
        _preferencePanel = nil;
    });
}
@end
