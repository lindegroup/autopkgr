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
        [[LGJSSDistributionPoint keyInfoDict] enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSDictionary *obj, BOOL * _Nonnull stop) {
            NSString *typeString = obj[kTypeString];
            if(!typeString) {
                return;
            }
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:obj[kTypeString] action:nil keyEquivalent:@""];
            item.tag = key.integerValue;
            [_distPointTypePopupBT.menu addItem:item];
        }];
        [self chooseDistPointType:_distPointTypePopupBT];
    }

}

- (void)populateUI
{
    _distPointTypePopupBT.hidden = YES;
    _distPointTypeLabel.hidden = YES;

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
    _cancelBT.hidden = YES;
    _addBT.title = @"Done";
    _infoText.stringValue = quick_formatString(@"Edit %@", _distPoint.name ?: @"Distribution Point");

    [self chooseDistributionPointType:_distPoint.type];
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults...
    LGJSSDistributionPoint *distributionPoint = [[LGJSSDistributionPoint alloc] init];
    if (_distPoint){
        distributionPoint.typeString = _distPoint.typeString;
    } else {
        distributionPoint.typeString = _distPointTypePopupBT.title;
    }
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
    [self chooseDistributionPointType:sender.selectedTag];
}

- (void)chooseDistributionPointType:(JSSDistributionPointType )type
{
    NSArray *allTextFields = [self allTextFields];
    for (NSTextField *t in allTextFields){
        t.hidden = NO;
        t.enabled = YES;
    }

    [_distPointName.cell setPlaceholderString:@"Descriptive Name (optional)"];
    _distPointDomain.hidden = YES;
    _distPointDomainLabel.hidden = YES;
    _distPointURLLabel.stringValue = @"URL";

    switch (type) {
        case kLGJSSTypeFromJSS: {
            for (NSTextField *t in allTextFields){t.hidden = YES;}
            _distPointPassword.hidden = NO;
            _distPointPasswordLabel.hidden = NO;
            break;
        }
        case kLGJSSTypeAFP: {
            [_distPointPort.cell setPlaceholderString:@"548 (optional)"];
            [_distPointURL.cell setPlaceholderString:@"afp://casper.yourcompany.example"];
            break;
        }
        case kLGJSSTypeSMB: {
            _distPointDomain.hidden = NO;
            [_distPointDomain.cell setPlaceholderString:@"WORKGROUP (optional)"];

            _distPointDomainLabel.hidden = NO;
            [_distPointPort.cell setPlaceholderString:@"139 or 445 (optional)"];
            [_distPointURL.cell setPlaceholderString:@"smb://casper.yourcompany.example"];
            break;
        }
        case kLGJSSTypeJDS:
        case kLGJSSTypeCDP: {
            for (NSButton *b in allTextFields){b.hidden = YES;}
            break;
        }
        case kLGJSSTypeLocal: {
            _distPointURLLabel.stringValue = @"Mount Point";
            [_distPointURL.cell setPlaceholderString:@"/Path/To/Mount"];

            _distPointUserName.hidden = YES;
            _distPointUserNameLabel.hidden = YES;

            _distPointPassword.hidden = YES;
            _distPointPasswordLabel.hidden = YES;

            _distPointShareName.hidden = YES;
            _distPointShareNameLabel.hidden = YES;

            _distPointPort.hidden = YES;
            _distPointPortLabel.hidden = YES;
            break;
        }
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
    JSSDistributionPointType type = _distPointPassword.selectedTag;
    switch (type) {
        case kLGJSSTypeFromJSS: {
            return @[_distPointPassword];
            break;
        }
        case kLGJSSTypeAFP:
        case kLGJSSTypeSMB: {
            return @[ _distPointName,
                      _distPointURL,
                      _distPointUserName,
                      _distPointPassword ];
            break;
        }
        case kLGJSSTypeJDS:
        case kLGJSSTypeCDP: {
            break;
        }
        case kLGJSSTypeLocal: {
            return @[ _distPointName,
                      _distPointURL,];
            break;
        }
        default: {
            break;
        }
    }
    return @[];
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
