//
//  LGJSSDistributionPointsPrefPanel.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 11/5/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGJSSDistributionPointsPrefPanel.h"
#import "LGJSSDistributionPoint.h"
#import "LGJSSImporterIntegration.h"
#import "LGAutoPkgr.h"

@interface LGJSSDistributionPointsPrefPanel () <NSWindowDelegate>

@end

@implementation LGJSSDistributionPointsPrefPanel {
    LGJSSDistributionPoint *_distPoint;
}

- (id)init
{
    return [self initWithWindowNibName:NSStringFromClass([self class])];
}

- (instancetype)initWithDistPoint:(LGJSSDistributionPoint *)distPoint
{
    self = [self init];
    if (self) {
        _distPoint = distPoint;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;

    [_distPointTypePopupBT removeAllItems];

    // We need to do this dance because it seems that when the class is initialized
    // the NSTextFields are nil until the window is loaded.
    if (_distPoint) {
        [self populateUI];
    } else {
        [_distPointTypePopupBT addItemsWithTitles:@[@"AFP",@"SMB",@"JDS",@"CDP",@"Local"]];
    }

    [self chooseDistPointType:_distPointTypePopupBT];
}

- (void)populateUI
{
    [_distPointTypePopupBT addItemWithTitle:_distPoint.typeString];
    [_distPointTypePopupBT setEnabled:NO];
    if (_distPoint.type == kLGJSSTypeLocal){
        _distPointURL.safe_stringValue = _distPoint.mount_point;
        _distPointName.safe_stringValue = _distPoint.share_name;
    } else {
        _distPointName.safe_stringValue = _distPoint.name;

        _distPointUserName.safe_stringValue = _distPoint.username;
        _distPointPassword.safe_stringValue = _distPoint.password;

        _distPointURL.safe_stringValue = _distPoint.URL;
        _distPointPort.safe_stringValue = _distPoint.port;
        _distPointShareName.safe_stringValue = _distPoint.share_name;

        _distPointDomain.safe_stringValue = _distPoint.domain;
    }

    [_distPointTypePopupBT selectItemWithTitle:_distPoint.typeString];

    _cancelBT.hidden = YES;
    _addBT.title = @"Done";
    _infoText.stringValue = NSLocalizedStringFromTable(@"Edit Distribution Point", @"LocalizableJSSImporter", nil);
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults...
    LGJSSDistributionPoint *distributionPoint = [[LGJSSDistributionPoint alloc] init];
    distributionPoint.typeString = _distPointTypePopupBT.title;
    distributionPoint.password = _distPointPassword.safe_stringValue;
    distributionPoint.username = _distPointUserName.safe_stringValue;
    distributionPoint.URL = _distPointURL.safe_stringValue;
    distributionPoint.share_name = _distPointShareName.safe_stringValue;
    distributionPoint.domain = _distPointDomain.safe_stringValue;
    distributionPoint.port = _distPointPort.safe_stringValue;
    distributionPoint.name = _distPointName.safe_stringValue;

    if ([distributionPoint save]) {
        [self closePanel:nil];
    } else {
        [self hilightRequiredTypes];
    }
}

- (IBAction)chooseDistPointType:(NSPopUpButton *)sender
{
    NSArray *allTextFields = [self allTextFields];
    for (NSButton *b in allTextFields){
        b.hidden = NO;
        b.enabled = YES;
    }

    [_distPointName.cell setPlaceholderString:@"Descriptive Name (optional)"];
    [_distPointDomain setHidden:YES];
    [_distPointDomainLabel setHidden:YES];

    _distPointURLLabel.stringValue = @"URL";
    if ([sender.title isEqualToString:@"AFP"]) {
        [_distPointPort.cell setPlaceholderString:@"548 (optional)"];
        [_distPointURL.cell setPlaceholderString:@"afp://casper.yourcompany.example"];

    } else if ([sender.title isEqualToString:@"SMB"]) {
        [_distPointDomain setHidden:NO];
        [_distPointDomain.cell setPlaceholderString:@"WORKGROUP (optional)"];

        [_distPointDomainLabel setHidden:NO];
        [_distPointPort.cell setPlaceholderString:@"139 or 445 (optional)"];
        [_distPointURL.cell setPlaceholderString:@"smb://casper.yourcompany.example"];

    } else if ([sender.title isEqualToString:@"JDS"] ||
               [sender.title isEqualToString:@"CDP"]) {
        for (NSButton *b in allTextFields){b.hidden = YES;}

    } else if ([sender.title isEqualToString:@"Local"]) {
        _distPointURLLabel.stringValue = @"Mount Point";
        [_distPointURL.cell setPlaceholderString:@"/Path/To/Mount"];

        _distPointUserName.hidden = YES;
        _distPointUserNameLabel.hidden = YES;
        //
        _distPointPassword.hidden = YES;
        _distPointPasswordLabel.hidden = YES;
        //
        _distPointShareName.hidden = YES;
        _distPointShareNameLabel.hidden = YES;
        //
        _distPointPort.hidden = YES;
        _distPointPortLabel.hidden = YES;
        //
    }
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp endSheet:self.window];
}

- (void)closePanel:(id)sender
{
    [NSApp endSheet:self.window];
}

#pragma mark - Utility
- (void)hilightRequiredTypes
{
    NSDictionary *redDict = @{
        NSForegroundColorAttributeName : [NSColor redColor],
        NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
    };

    NSDictionary *grayDict = @{
        NSForegroundColorAttributeName : [NSColor grayColor],
        NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]],
    };

    for (NSTextField *type in [self allTextFields]) {
        if (!type.stringValue.length) {
            NSString *string = [[type.cell placeholderAttributedString] string];
            if (!string) {
                string = [type.cell placeholderString] ;
            }

            NSMutableAttributedString *grayString = [[NSMutableAttributedString alloc] initWithString:string attributes:grayDict];

            [[type cell] setPlaceholderAttributedString:grayString];
        }
    }

    for (NSTextField *type in [self requiredForType]) {
        NSString *string = [[type.cell placeholderAttributedString] string];
        if (!string) {
            string = [type.cell placeholderString];
        }

        NSMutableAttributedString *redString = [[NSMutableAttributedString alloc] initWithString:string attributes:redDict];

        [[type cell] setPlaceholderAttributedString:redString];
    }
}

- (NSArray *)requiredForType
{
    NSString *type = _distPointTypePopupBT.title;

    NSMutableArray *types = [NSMutableArray arrayWithObjects: _distPointName,
                                                              _distPointURL, nil];

    if ([type isEqualToString:@"AFP"] || [type isEqualToString:@"SMB"]) {
        [types addObjectsFromArray:@[ _distPointUserName,
                                      _distPointPassword ]];
    }

    return types.copy;
}

- (NSArray *)allTextFields
{
    return @[ _distPointDomain, _distPointDomainLabel,
              _distPointName, _distPointNameLabel,
              _distPointPassword, _distPointPasswordLabel,
              _distPointPort, _distPointPortLabel,
              _distPointShareName, _distPointShareNameLabel,
              _distPointURL, _distPointURLLabel,
              _distPointUserName, _distPointUserNameLabel ];
}

@end
