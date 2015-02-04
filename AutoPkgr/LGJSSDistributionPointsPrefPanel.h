//
//  LGJSSDistributionPointsPrefPanel.h
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

#import <Cocoa/Cocoa.h>
#import "LGAutoPkgr.h"

@interface LGJSSDistributionPointsPrefPanel : NSWindowController

- (instancetype)initWithDistPointDictionary:(NSDictionary *)dict;

@property (weak) IBOutlet NSTextField *distPointName;
@property (weak) IBOutlet NSTextField *distPointNameLabel;
@property (weak) IBOutlet NSTextField *distPointURL;
@property (weak) IBOutlet NSTextField *distPointURLLabel;
@property (weak) IBOutlet NSTextField *distPointUserName;
@property (weak) IBOutlet NSTextField *distPointUserNameLabel;
@property (weak) IBOutlet NSTextField *distPointPassword;
@property (weak) IBOutlet NSTextField *distPointPasswordLabel;
@property (weak) IBOutlet NSTextField *distPointShareName;
@property (weak) IBOutlet NSTextField *distPointShareNameLabel;
@property (weak) IBOutlet NSTextField *distPointPort;
@property (weak) IBOutlet NSTextField *distPointPortLabel;
@property (weak) IBOutlet NSTextField *distPointDomain;
@property (weak) IBOutlet NSTextField *distPointDomainLabel;

@property (weak) IBOutlet NSPopUpButton *distPointTypePopupBT;
@property (weak) IBOutlet NSButton *cancelBT;
@property (weak) IBOutlet NSButton *addBT;
@property (weak) IBOutlet NSTextField *infoText;

- (IBAction)addDistPoint:(NSButton *)sender;
- (IBAction)chooseDistPointType:(NSPopUpButton *)sender;

- (IBAction)closePanel:(id)sender;

@end
