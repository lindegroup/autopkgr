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
#import "LGJSSImporterIntegration.h"
#import "LGAutoPkgr.h"

@interface LGJSSDistributionPointsPrefPanel () <NSWindowDelegate>

@end

@implementation LGJSSDistributionPointsPrefPanel {
    NSDictionary *_editRepoDict;
}

- (id)init
{
    return [self initWithWindowNibName:NSStringFromClass([self class])];
}

- (instancetype)initWithDistPointDictionary:(NSDictionary *)dict
{
    self = [self init];
    if (self) {
        _editRepoDict = dict;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.window.delegate = self;

    // We need to do this dance because it seems that when the class is initialized
    // the NSTextFields are nil until the window is loaded.
    if (_editRepoDict) {
        [self populateWithDictionary];
    }

    [self chooseDistPointType:_distPointTypePopupBT];
}

- (void)populateWithDictionary
{
    _distPointDomain.safe_stringValue = _editRepoDict[kLGJSSDistPointWorkgroupDomainKey];
    _distPointName.safe_stringValue = _editRepoDict[kLGJSSDistPointNameKey];
    _distPointPassword.safe_stringValue = _editRepoDict[kLGJSSDistPointPasswordKey];
    _distPointPort.safe_stringValue = _editRepoDict[kLGJSSDistPointPortKey];
    _distPointShareName.safe_stringValue = _editRepoDict[kLGJSSDistPointSharePointKey];
    _distPointURL.safe_stringValue = _editRepoDict[kLGJSSDistPointURLKey];
    _distPointUserName.safe_stringValue = _editRepoDict[kLGJSSDistPointUserNameKey];
    [_distPointTypePopupBT selectItemWithTitle:_editRepoDict[kLGJSSDistPointTypeKey]];

    _cancelBT.hidden = YES;
    _addBT.title = @"Done";
    _infoText.stringValue = NSLocalizedStringFromTable(@"Edit Distribution Point", @"LocalizableJSSImporter", nil);
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults...
    LGJSSImporterDefaults *defaults = [LGJSSImporterDefaults new];

    NSMutableOrderedSet *workingSet = [[NSMutableOrderedSet alloc] initWithArray:defaults.JSSRepos];

    NSString *password = _distPointPassword.safe_stringValue;
    NSString *userName = _distPointUserName.safe_stringValue;
    NSString *url = _distPointURL.safe_stringValue;
    NSString *shareName = _distPointShareName.safe_stringValue;
    NSString *domain = _distPointDomain.safe_stringValue;
    NSString *port = _distPointPort.safe_stringValue;
    NSString *type = _distPointTypePopupBT.title;
    NSString *name = _distPointName.safe_stringValue;

    NSMutableDictionary *distPoint = [[NSMutableDictionary alloc] init];

    if ([self meetsRequirementsForType]) {
        [distPoint setObject:type forKey:kLGJSSDistPointTypeKey];
        [distPoint setObject:password forKey:kLGJSSDistPointPasswordKey];
        [distPoint setObject:url forKey:kLGJSSDistPointURLKey];
        [distPoint setObject:userName forKey:kLGJSSDistPointUserNameKey];

        if (name) {
            [distPoint setObject:name forKey:kLGJSSDistPointNameKey];
        }

        if ([type isEqualToString:@"AFP"] || [type isEqualToString:@"SMB"]) {
            if (shareName) {
                [distPoint setObject:shareName forKey:kLGJSSDistPointSharePointKey];
            }

            if (port) {
                [distPoint setObject:port forKey:kLGJSSDistPointPortKey];
            }

            if (domain && [type isEqualToString:@"SMB"]) {
                [distPoint setObject:domain forKey:kLGJSSDistPointWorkgroupDomainKey];
            }
        }

        if (_editRepoDict) {
            NSUInteger index = [workingSet indexOfObjectPassingTest:
                                               ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                                    return [dict isEqualToDictionary:_editRepoDict];
                                               }];

            if (index != NSNotFound) {
                [workingSet replaceObjectAtIndex:index withObject:distPoint];
            }
            _editRepoDict = nil;
        } else {
            [workingSet addObject:distPoint];
        }

        if (workingSet.count >= defaults.JSSRepos.count) {
            defaults.JSSRepos = [workingSet array];
            [self closePanel:nil];
        }
    } else {
        [self hilightRequiredTypes];
    }
}

- (IBAction)chooseDistPointType:(NSPopUpButton *)sender
{
    [_distPointName setEnabled:YES];
    [_distPointPort setHidden:NO];
    [_distPointShareName setHidden:NO];
    [_distPointName.cell setPlaceholderString:@"Descriptive Name (optional)"];

    // Hide Labels too
    [_distPointPortLabel setHidden:NO];
    [_distPointShareNameLabel setHidden:NO];

    if ([sender.title isEqualToString:@"AFP"]) {
        [_distPointDomain setHidden:YES];
        [_distPointDomainLabel setHidden:YES];

        [_distPointPort.cell setPlaceholderString:@"548 (optional)"];
        [_distPointURL.cell setPlaceholderString:@"afp://casper.yourcompany.example"];

    } else if ([sender.title isEqualToString:@"SMB"]) {
        [_distPointDomain setHidden:NO];
        [_distPointDomain.cell setPlaceholderString:@"WORKGROUP (optional)"];

        [_distPointDomainLabel setHidden:NO];
        [_distPointPort.cell setPlaceholderString:@"139 or 445 (optional)"];
        [_distPointURL.cell setPlaceholderString:@"smb://casper.yourcompany.example"];

    } else if ([sender.title isEqualToString:@"JDS"]) {
        [_distPointName setEnabled:NO];
        [_distPointName.cell setPlaceholderString:@"<N/A>"];

        [_distPointURL.cell setPlaceholderString:@"http://casper.yourcompany.example"];

        [_distPointPort setHidden:YES];
        [_distPointPortLabel setHidden:YES];

        [_distPointShareName setHidden:YES];
        [_distPointShareNameLabel setHidden:YES];

        [_distPointDomain setHidden:YES];
        [_distPointDomainLabel setHidden:YES];
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
        NSString *string = [[type.cell placeholderAttributedString] string];
        if (!string) {
            string = [type.cell placeholderString];
        }

        NSMutableAttributedString *grayString = [[NSMutableAttributedString alloc] initWithString:string attributes:grayDict];

        [[type cell] setPlaceholderAttributedString:grayString];
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

- (BOOL)meetsRequirementsForType
{
    for (NSTextField *type in [self requiredForType]) {
        if (!type.safe_stringValue) {
            return NO;
        }
    }
    return YES;
}

- (NSArray *)requiredForType
{
    NSString *type = _distPointTypePopupBT.title;

    NSMutableArray *types = [NSMutableArray arrayWithObjects:
                                                _distPointURL,
                                                _distPointUserName,
                                                _distPointPassword,
                                                nil];

    if ([type isEqualToString:@"AFP"] || [type isEqualToString:@"SMB"]) {
        [types addObject:_distPointShareName];
    }

    if ([type isEqualToString:@"SMB"]) {
        //        [types addObject:_distPointDomain];
    }

    return [NSArray arrayWithArray:types];
}

- (NSArray *)allTextFields
{
    return @[ _distPointDomain,
              _distPointName,
              _distPointPassword,
              _distPointPort,
              _distPointShareName,
              _distPointURL,
              _distPointUserName ];
}
@end
