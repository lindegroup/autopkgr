//
//  LGJamfDistributionPointsPrefPanel.m
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

#import "LGAutoPkgr.h"
#import "LGJamfDistributionPoint.h"
#import "LGJamfDistributionPointsPrefPanel.h"
#import "LGJamfUploaderIntegration.h"

#import "NSTableView+Resizing.h"
#import "NSTextField+changeHandle.h"
#import <Quartz/Quartz.h>

#pragma mark - Table View Cell
@interface LGJamfDistPointTableViewCell : NSTableCellView
@property (strong, nonatomic) IBOutlet NSTextField *input;
@end

@implementation LGJamfDistPointTableViewCell
@end

#pragma mark - Panel
@interface LGJamfDistributionPointsPrefPanel () <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSPopUpButton *distPointTypePopupBT;
@property (weak) IBOutlet NSTextField *distPointTypeLabel;

@property (weak) IBOutlet NSButton *cancelBT;
@property (weak) IBOutlet NSButton *addBT;
@property (weak) IBOutlet NSTextField *infoText;

- (IBAction)addDistPoint:(NSButton *)sender;
- (IBAction)chooseDistPointType:(NSPopUpButton *)sender;

- (IBAction)closePanel:(id)sender;
@end

@implementation LGJamfDistributionPointsPrefPanel {
    LGJamfDistributionPoint *_distPoint;
    NSTableView *_tableView;
    NSMutableOrderedSet *_dpRows;
}

#pragma mark - Init / Loading
- (id)init
{
    return [self initWithWindowNibName:NSStringFromClass([self class])];
}

- (instancetype)initWithDistPoint:(LGJamfDistributionPoint *)distPoint
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

    // We need to do this dance because it seems that when the class is initialized the NSTextFields are nil until the window is loaded.

    if (_distPoint) {
        _distPointTypePopupBT.hidden = YES;
        _distPointTypeLabel.hidden = YES;

        _cancelBT.hidden = YES;
        _addBT.title = @"Done";
        _infoText.stringValue = quick_formatString(@"Edit %@", _distPoint.name ?: @"Distribution Point");

        [self chooseDistributionPointType:_distPoint.type];
    }
    else {
        [self populatePopupButton:_distPointTypePopupBT];
        [self chooseDistPointType:_distPointTypePopupBT];
    }
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults.
    if ([_distPoint save]) {
        [self closePanel:nil];
    }
    else {
        [self hilightRequiredTypes];
    }
}

- (IBAction)chooseDistPointType:(NSPopUpButton *)sender
{
    _distPoint = [[LGJamfDistributionPoint alloc] initWithType:sender.selectedTag];
    [self chooseDistributionPointType:sender.selectedTag];
}

- (void)chooseDistributionPointType:(JamfDistributionPointType)type
{
    NSDictionary *dict = [LGJamfDistributionPoint keyJamfInfoDict][@(type)];
    _dpRows = [[NSMutableOrderedSet alloc] initWithArray:dict[kJamfRequired]];
    [_dpRows addObjectsFromArray:dict[kJamfOptional]];
    [_dpRows removeObject:kLGJamfDistPointTypeKey];
    // When it's set from a Jamf, the share name isn't editable either, so pop it here.
    if (type == kLGJamfTypeFromJamf) {
        [_dpRows removeObject:kLGJamfDistPointNameKey];
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

    LGJamfDistPointTableViewCell *view = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

    if ([view.identifier isEqualToString:@"main"]) {
        NSString *key = _dpRows[row];
        view.textField.stringValue = [[key stringByReplacingOccurrencesOfString:@"_" withString:@" "].capitalizedString stringByAppendingString:@":"];

        BOOL changeToSecureText = [key isEqualToString:kLGJamfDistPointPasswordKey] && ![view.input isKindOfClass:[NSSecureTextField class]];
        BOOL changeToClearText = ![key isEqualToString:kLGJamfDistPointPasswordKey] &&
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
    NSMutableDictionary *keyInfoDict = [[LGJamfDistributionPoint keyJamfInfoDict] mutableCopy];

    // Enumerate over the enabled dict to see if there are any distribution point types that can only have one instance, and remove them.
    NSArray *enabled = [LGJamfDistributionPoint enabledDistributionPoints];
    [enabled enumerateObjectsUsingBlock:^(LGJamfDistributionPoint *dp, NSUInteger idx, BOOL *stop) {
        switch (dp.type) {
        case kLGJamfTypeJDS:
        case kLGJamfTypeCDP:
        case kLGJamfTypeLocal: {
            [keyInfoDict removeObjectForKey:@(dp.type)];
            break;
        }
        default:
            break;
        }
    }];

    [keyInfoDict enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSDictionary *obj, BOOL *stop) {
        NSString *typeString = obj[kJamfTypeString];
        if (!typeString) {
            return;
        }

        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:obj[kJamfTypeString] action:nil keyEquivalent:@""];
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

    NSArray *required = [LGJamfDistributionPoint keyJamfInfoDict][@(_distPoint.type)][kJamfRequired];

    [_tableView enumerateAvailableRowViewsUsingBlock:^(__kindof NSTableRowView *rowView, NSInteger row) {
        NSTextField *input = [(LGJamfDistPointTableViewCell *)rowView.subviews.firstObject input];
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

- (NSDictionary *)placeholderDictForType:(JamfDistributionPointType)type
{
    NSString *port = @"";
    NSString *url = @"";
    NSString *label = @"Distribution Point";
    NSString *share = @"JamfShare";
    switch (type) {
    case kLGJamfTypeAFP: {
        port = @"548 (optional)";
        url = @"afp://jamf.example.com";
        break;
    }
    case kLGJamfTypeSMB: {
        port = @"139 or 445 (optional)";
        url = @"smb://jamf.example.com";
        break;
    }
    case kLGJamfTypeLocal: {
        label = @"Mount Point";
        share = @"JamfShare";
        break;
    }
    default: {
        break;
    }
    }
    return @{ kLGJamfDistPointPortKey : port,
              kLGJamfDistPointURLKey : url,
              kLGJamfDistPointNameKey : label,
              kLGJamfDistPointSharePointKey : share,
              kLGJamfDistPointMountPointKey : @"/Users/Shared/JamfShare",
              kLGJamfDistPointUserNameKey : @"rwuser",
              kLGJamfDistPointWorkgroupDomainKey : @"WORKGROUP",
              kLGJamfDistPointPasswordKey : @"Password",
    };
}

@end
