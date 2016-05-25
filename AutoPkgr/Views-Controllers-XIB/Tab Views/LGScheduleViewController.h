//
//  LGScheduleViewController.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
//  Copyright 2015 Eldon Ahrold
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

#import <Cocoa/Cocoa.h>
#import "LGTabViewControllerBase.h"

@interface LGScheduleViewController : LGTabViewControllerBase

#pragma mark - Schedule
#pragma mark-- Outlets --
@property (weak) IBOutlet NSMatrix *scheduleTypeMatrix;
@property (weak) IBOutlet NSTextField *scheduleIntervalTF;
@property (weak) IBOutlet NSButton *scheduleEnabledBT;

@property (weak) IBOutlet NSPopUpButton *dailyHourPopupBT;
@property (weak) IBOutlet NSPopUpButton *weeklyHourPopupBT;
@property (weak) IBOutlet NSPopUpButton *weeklyDayPopupBT;



/* These are set externally and not part of the
 * LGScheduleViewController.xib. Currently the cancel button
 * is referenced by LGConfigurationWindowController's progress panel.
 * The scheduleMenuItem is referenced by the status menu item. */
@property (weak, nonatomic) NSMenuItem *scheduleMenuItem;

#pragma mark-- IBActions --
- (IBAction)changeSchedule:(id)sender;


@end
