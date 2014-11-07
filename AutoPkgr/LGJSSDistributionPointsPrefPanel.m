//
//  LGJSSDistributionPointsPrefPanel.m
//  AutoPkgr
//
//  Created by Eldon on 11/5/14.
//  Copyright 2014 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGJSSDistributionPointsPrefPanel.h"

@interface LGJSSDistributionPointsPrefPanel ()

@end

@implementation LGJSSDistributionPointsPrefPanel {
    NSDictionary *_editRepoDict;
}

-(id)init {
    return  [self initWithWindowNibName:@"LGJSSDistributionPointsPrefPanel"];
}

-(instancetype)initWithDistPointDictionary:(NSDictionary *)dict {
    self = [self init];
    if (self) {
        _editRepoDict = dict;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    // We need to do this dance because it seems that when the class is initialized
    // the NSTextFields are nil until the window is loaded.
    if (_editRepoDict) {
        [self populateWithDictionary];
    }

    [self chooseDistPointType:_distPointTypePopupBT];
}

- (void)populateWithDictionary
{
    _distPointDomain.safeStringValue = _editRepoDict[@"domain"];
    _distPointName.safeStringValue = _editRepoDict[@"name"];
    _distPointPassword.safeStringValue = _editRepoDict[@"password"];
    _distPointPort.safeStringValue = _editRepoDict[@"port"];
    _distPointShareName.safeStringValue = _editRepoDict[@"share_name"];
    _distPointURL.safeStringValue = _editRepoDict[@"URL"];
    _distPointUserName.safeStringValue = _editRepoDict[@"username"];
    [_distPointTypePopupBT selectItemWithTitle:_editRepoDict[@"type"]];
    
    [_cancelBT setHidden:YES];
    [_addBT setTitle:@"Done"];
    [_infoText setStringValue:@"Edit Distribution Point"];
}

- (void)addDistPoint:(NSButton *)sender
{
    // Save distpoint to defaults...
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    NSMutableOrderedSet *workingSet = [[NSMutableOrderedSet alloc] initWithArray:defaults.JSSRepos];

    NSString *password = _distPointPassword.safeStringValue;
    NSString *userName = _distPointUserName.safeStringValue;
    NSString *url = _distPointURL.safeStringValue;
    NSString *shareName = _distPointShareName.safeStringValue;
    NSString *domain = _distPointDomain.safeStringValue;
    NSString *port = _distPointPort.safeStringValue;
    NSString *type = _distPointTypePopupBT.title;
    NSString *name = _distPointName.safeStringValue;

    NSMutableDictionary *distPoint = [[NSMutableDictionary alloc] init];

    if ([self meetsRequirementsForType]) {
        [distPoint setObject:type forKey:@"type"];
        [distPoint setObject:password forKey:@"password"];
        [distPoint setObject:url forKey:@"URL"];
        [distPoint setObject:userName forKey:@"username"];

        if (name) {
            [distPoint setObject:name forKey:@"name"];
        }

        if ([type isEqualToString:@"AFP"] || [type isEqualToString:@"SMB"]) {
            if (shareName) {
                [distPoint setObject:shareName forKey:@"share_name"];
            }

            if (port) {
                [distPoint setObject:port forKey:@"port"];
            }

            if (domain && [type isEqualToString:@"SMB"]) {
                [distPoint setObject:domain forKey:@"domain"];
            }
        }

        if (_editRepoDict) {
            NSUInteger index = [workingSet indexOfObjectPassingTest:
                                ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop)
                                {
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
    if ([sender.title isEqualToString:@"AFP"]) {
        [_distPointPort setHidden:NO];
        [_distPointShareName setHidden:NO];
        [_distPointDomain setHidden:YES];

    } else if ([sender.title isEqualToString:@"SMB"]) {
        [_distPointPort setHidden:NO];
        [_distPointShareName setHidden:NO];
        [_distPointDomain setHidden:NO];
        
    } else if ([sender.title isEqualToString:@"JDS"]) {
        [_distPointPort setHidden:YES];
        [_distPointShareName setHidden:YES];
        [_distPointDomain setHidden:YES];
    }
}

- (void)closePanel:(id)sender
{
    [NSApp endSheet:self.window];
}

#pragma mark - Utility
- (void)hilightRequiredTypes
{
    NSDictionary *redDict = @{NSForegroundColorAttributeName: [NSColor redColor],
                          NSFontAttributeName:[NSFont systemFontOfSize:[NSFont systemFontSize]],
                          };

    NSDictionary *grayDict = @{NSForegroundColorAttributeName: [NSColor grayColor],
                           NSFontAttributeName:[NSFont systemFontOfSize:[NSFont systemFontSize]],
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
    for (NSTextField* type in [self requiredForType]) {
        if (!type.safeStringValue) {
            return NO;
        }
    }
    return YES;
}

- (NSArray *)requiredForType
{
    NSString *type = _distPointTypePopupBT.title;
    NSMutableArray *types = [NSMutableArray arrayWithArray:@[ _distPointURL, _distPointUserName, _distPointPassword ]];
    if ([type isEqualToString:@"AFP"] || [type isEqualToString:@"SMB"]) {
        [types addObject:_distPointShareName];
    }

    if ([type isEqualToString:@"SMB"]) {
        [types addObject:_distPointDomain];
    }

    return [NSArray arrayWithArray:types];
}

- (NSArray *)allTextFields
{
    return @[_distPointDomain,_distPointName,_distPointPassword,_distPointPort,_distPointShareName,_distPointURL,_distPointUserName];
}
@end
