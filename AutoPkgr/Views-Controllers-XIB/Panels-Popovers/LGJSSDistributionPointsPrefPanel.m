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

#import "NSTextField+changeHandle.h"
#import "NSTableView+Resizing.h"
#import <Quartz/Quartz.h>

#pragma mark - Table View Cell
@interface LGJSSDistPointTableViewCell : NSTableCellView
@property (strong, nonatomic) IBOutlet NSTextField *input;
@end

@implementation LGJSSDistPointTableViewCell
@end

#pragma mark - Panel
@interface LGJSSDistributionPointsPrefPanel () <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSPopUpButton *distPointTypePopupBT;
@property (weak) IBOutlet NSTextField *distPointTypeLabel;

@property (weak) IBOutlet NSButton *cancelBT;
@property (weak) IBOutlet NSButton *addBT;
@property (weak) IBOutlet NSTextField *infoText;

- (IBAction)addDistPoint:(NSButton *)sender;
- (IBAction)chooseDistPointType:(NSPopUpButton *)sender;

- (IBAction)closePanel:(id)sender;
@end

@implementation LGJSSDistributionPointsPrefPanel {
    LGJSSDistributionPoint *_distPoint;
    NSTableView *_tableView;
    NSMutableOrderedSet *_dpRows;
}

#pragma mark - Init / Loading
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
        _distPointTypePopupBT.hidden = YES;
        _distPointTypeLabel.hidden = YES;

        _cancelBT.hidden = YES;
        _addBT.title = @"Done";
        _infoText.stringValue = quick_formatString(@"Edit %@", _distPoint.name ?: @"Distribution Point");

        [self chooseDistributionPointType:_distPoint.type];
    } else {
        [self populatePopupButton:_distPointTypePopupBT];
        [self chooseDistPointType:_distPointTypePopupBT];
    }
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults...
    if ([_distPoint save]) {
        [self closePanel:nil];
    } else {
        [self hilightRequiredTypes];
    }
}

- (IBAction)chooseDistPointType:(NSPopUpButton *)sender
{
    _distPoint = [[LGJSSDistributionPoint alloc] initWithType:sender.selectedTag];
    [self chooseDistributionPointType:sender.selectedTag];
}

- (void)chooseDistributionPointType:(JSSDistributionPointType)type
{
    NSDictionary *dict = [LGJSSDistributionPoint keyInfoDict][@(type)];
    _dpRows = [[NSMutableOrderedSet alloc] initWithArray:dict[kRequired]];
    [_dpRows addObjectsFromArray:dict[kOptional]];
    [_dpRows removeObject:kLGJSSDistPointTypeKey];
    // When it's set from a JSS, the share name isn't editable either, so pop it here.
    if (type == kLGJSSTypeFromJSS) {
        [_dpRows removeObject:kLGJSSDistPointNameKey];
    }
    [_tableView reloadData];
}

#pragma mark - Table View delegate & dataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    _tableView = tableView;
    NSInteger count = _dpRows.count;
    [tableView resized_Height:(count * tableView.rowHeight) * 1.1];
    return count;
};

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    LGJSSDistPointTableViewCell *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

    if ([view.identifier isEqualToString:@"main"]) {
        NSString *key = _dpRows[row];
        view.textField.stringValue = [[key stringByReplacingOccurrencesOfString:@"_" withString:@" "].capitalizedString stringByAppendingString:@":"];

        BOOL changeToSecureText = [key isEqualToString:kLGJSSDistPointPasswordKey] && ![view.input isKindOfClass:[NSSecureTextField class]];
        BOOL changeToClearText = ![key isEqualToString:kLGJSSDistPointPasswordKey] &&
                                 [view.input isKindOfClass:[NSSecureTextField class]];

        if (changeToSecureText || changeToClearText) {
            // Swap out a secure text field for the regular text field.
            NSRect r = view.input.frame;

            // The old input y origin isn't translating correctly so pad it by -3.
            NSRect frame = changeToSecureText ? NSMakeRect(r.origin.x, (r.origin.y - 3), r.size.width, r.size.height) : r;

            Class textField = changeToSecureText ? [NSSecureTextField class] : [NSTextField class];

            id input = [[textField alloc] initWithFrame:frame];
            [view.input removeFromSuperview];

            [view addSubview:input];
            [view setInput:input];
        }

        view.input.placeholderString = [self placeholderDictForType:_distPointTypePopupBT.selectedTag][key];
        view.input.identifier = key;
        view.input.refusesFirstResponder = NO;

        [view.input textChanged:^(NSString *newVal) {
            [_distPoint setValue:newVal forKey:key];
        }];

        if (_distPoint) {
            NSString *string = [_distPoint valueForKey:key];
            if (string.length) {
                view.input.stringValue = string;
            }
        }
    }
    return view;
}

#pragma mark - Sheet
- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp endSheet:self.window];
}

- (void)closePanel:(id)sender
{
    [NSApp endSheet:self.window];
}

#pragma mark - Util
- (void)populatePopupButton:(NSPopUpButton *)button
{
    NSMutableDictionary *keyInfoDict = [[LGJSSDistributionPoint keyInfoDict] mutableCopy];

    // Enumerate over the enabled dict to see if there are any dp types
    // that can only have one instance, and remove them if that is the case.
    NSArray *enabled = [LGJSSDistributionPoint enabledDistributionPoints];
    [enabled enumerateObjectsUsingBlock:^(LGJSSDistributionPoint *dp, NSUInteger idx, BOOL *stop) {
        switch (dp.type) {
        case kLGJSSTypeJDS:
        case kLGJSSTypeCDP:
        case kLGJSSTypeLocal: {
            [keyInfoDict removeObjectForKey:@(dp.type)];
            break;
        }
        default:
            break;
        }
    }];

    [keyInfoDict enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSDictionary *obj, BOOL *stop) {
        NSString *typeString = obj[kTypeString];
        if (!typeString) {
            return;
        }

        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:obj[kTypeString] action:nil keyEquivalent:@""];
        item.tag = key.integerValue;
        [button.menu addItem:item];
    }];
}

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

    NSArray *required = [LGJSSDistributionPoint keyInfoDict][@(_distPoint.type)][kRequired];

    [_tableView enumerateAvailableRowViewsUsingBlock:^(__kindof NSTableRowView *rowView, NSInteger row) {
        NSTextField *input = [(LGJSSDistPointTableViewCell *)rowView.subviews.firstObject input];
        NSString *identifier = input.identifier;

        NSString *string = [[input.cell placeholderAttributedString] string];
        if (!string) {
            string = [input.cell placeholderString];
        }
        BOOL missingRequired = ([required containsObject:identifier] && !input.stringValue.length);
        NSAttributedString *colorString = [[NSMutableAttributedString alloc] initWithString:string
                                                                                 attributes:missingRequired ? redDict : grayDict];
        [[input cell] setPlaceholderAttributedString:colorString];
    }];
}

- (NSDictionary *)placeholderDictForType:(JSSDistributionPointType)type
{
    NSString *port = @"";
    NSString *url = @"";
    NSString *label = @"Distribution Point";
    NSString *share = @"CasperShare";
    switch (type) {
    case kLGJSSTypeAFP: {
        port = @"548 (optional)";
        url = @"afp://casper.pretendo.com";
        break;
    }
    case kLGJSSTypeSMB: {
        port = @"139 or 445 (optional)";
        url = @"smb://casper.pretendo.com";
        break;
    }
    case kLGJSSTypeLocal: {
        label = @"Mount Point";
        share = @"JAMFdistrib";
        break;
    }
    default: {
        break;
    }
    }
    return @{ kLGJSSDistPointPortKey : port,
              kLGJSSDistPointURLKey : url,
              kLGJSSDistPointNameKey : label,
              kLGJSSDistPointSharePointKey : share,
              kLGJSSDistPointMountPointKey : @"/Users/Shared/JAMFdistrib",
              kLGJSSDistPointUserNameKey : @"rwuser",
              kLGJSSDistPointWorkgroupDomainKey : @"WORKGROUP",
              kLGJSSDistPointPasswordKey : @"Password",
    };
}

@end
