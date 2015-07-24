//
//  LGScheduleViewController.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
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

#import "LGScheduleViewController.h"
#import "LGPasswords.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgSchedule.h"
#import "LGTestPort.h"

#import <AHLaunchCtl/AHLaunchJobSchedule.h>

@interface LGScheduleViewController () {
    LGDefaults *_defaults;
}

@property (copy, nonatomic, readonly) id proposedSchedule;
@property (copy, nonatomic, readonly) id currentSchedule;
@property (nonatomic, assign) BOOL isCurrentlyScheduled;

@end

@implementation LGScheduleViewController
@synthesize currentSchedule = _currentSchedule;

- (void)awakeFromNib
{
    // Set up schedule settings
    id currentSchedule;
    _scheduleEnabledBT.state = [LGAutoPkgSchedule updateAppsIsScheduled:&currentSchedule];
    _scheduleMenuItem.state = _scheduleEnabledBT.state;
    [self updateIBOutletsWithSchedule:currentSchedule ?: self.proposedSchedule];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (NSString *)tabLabel
{
    return NSLocalizedString(@"Schedule", @"Tab label");
}

#pragma mark - Accessors
- (void)setScheduleMenuItem:(NSMenuItem *)scheduleMenuItem
{
    scheduleMenuItem.target = self;
    scheduleMenuItem.action = @selector(changeSchedule:);
    _scheduleMenuItem = scheduleMenuItem;
}

#pragma mark - Schedule Accessors
- (id)proposedSchedule
{
    id proposedSchedule = nil;
    switch (_scheduleTypeMatrix.selectedTag) {
    case 0:
        // Set it up to run every hour
        proposedSchedule = @(_scheduleIntervalTF.integerValue);
        break;
    case 1:
        // Set it up as a daily run at xx
        proposedSchedule = [AHLaunchJobSchedule dailyRunAtHour:_dailyHourPopupBT.selectedItem.tag minute:00];
        break;
    case 2:
        // Set it up to run weekly on xx at xx
        proposedSchedule = [AHLaunchJobSchedule weeklyRunOnWeekday:_weeklyDayPopupBT.selectedItem.tag hour:_weeklyHourPopupBT.selectedItem.tag];
        break;
    default:
        break;
    };
    return proposedSchedule;
}

- (id)currentSchedule
{
    if (self.isCurrentlyScheduled) {
        return _currentSchedule;
    }
    return nil;
}

- (BOOL)isCurrentlyScheduled
{
    id currentSchedule;
    if ((_isCurrentlyScheduled = [LGAutoPkgSchedule updateAppsIsScheduled:&currentSchedule])) {
        _currentSchedule = currentSchedule;
    }

    return _isCurrentlyScheduled;
}

- (void)updateIBOutletsWithSchedule:(id)scheduleOrInterval
{
    if ([scheduleOrInterval isKindOfClass:[AHLaunchJobSchedule class]]) {

        NSString *menuTitleString;
        if ([scheduleOrInterval dictionary].count == 2) {
            [_scheduleTypeMatrix selectCellWithTag:1];
            [_dailyHourPopupBT selectItemWithTag:[(AHLaunchJobSchedule *)scheduleOrInterval hour]];
            menuTitleString = [NSString stringWithFormat:NSLocalizedString(@"Run AutoPkg Daily at %@", nil), _dailyHourPopupBT.selectedItem.title];

        } else {
            [_scheduleTypeMatrix selectCellWithTag:2];
            [_weeklyHourPopupBT selectItemWithTag:[(AHLaunchJobSchedule *)scheduleOrInterval hour]];
            [_weeklyDayPopupBT selectItemWithTag:[(AHLaunchJobSchedule *)scheduleOrInterval weekday]];
            menuTitleString = [NSString stringWithFormat:NSLocalizedString(@"Run AutoPkg %@s at %@", nil), _weeklyDayPopupBT.selectedItem.title, _weeklyHourPopupBT.selectedItem.title];
        }
        _scheduleMenuItem.title = menuTitleString;

    } else if ([scheduleOrInterval isKindOfClass:[NSNumber class]]) {
        //
        [_scheduleTypeMatrix selectCellWithTag:0];
        _scheduleIntervalTF.stringValue = [scheduleOrInterval stringValue];

        _scheduleMenuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Run AutoPkg Every %@ Hours", nil), scheduleOrInterval];

    } else if (scheduleOrInterval) {
        NSAssert(NO, @"The schedule is not correctly formatted and cannot be handled.");
    }
}

- (IBAction)changeSchedule:(id)sender
{
    // Determine whether to start or stop the schedule...
    BOOL start;
    if ([sender isEqualTo:_scheduleMenuItem]) {
        // The status menu's `state` property isn't updated until after the
        // action is completed so use the inverse of the state property here.
        start = !_scheduleMenuItem.state;
    } else {
        start = _scheduleEnabledBT.state;
    }

    // First check for a few conditions that should just be returned from...
    if (start) {
        if ([self.currentSchedule isEqualTo:self.proposedSchedule]) {
            return;
        } else if ([sender isEqualTo:_scheduleIntervalTF] && _scheduleTypeMatrix.selectedTag != 0) {
            return;
        } else if ([sender isEqualTo:_dailyHourPopupBT] && _scheduleTypeMatrix.selectedTag != 1) {
            return;
        } else if ([sender isEqualTo:_weeklyHourPopupBT] || [sender isEqualTo:_weeklyDayPopupBT]) {
            if (_scheduleTypeMatrix.selectedTag != 2) {
                return;
            }
        }
    }

    /* Force a change if the action was triggered by changing a setting in
     * them matrix, or a schedule interval. */
    BOOL force = (![sender isEqualTo:_scheduleEnabledBT] && (![sender isEqualTo:_scheduleMenuItem]));

    /* If not enabled and the sender is from the the matrix
     * just update the IBOutlet settings. */
    if (!start && force) {
        return [self updateIBOutletsWithSchedule:self.proposedSchedule];
    }

    NSLog(@"%@ autopkg run schedule.", start ? @"Enabling" : @"Disabling");
    [LGAutoPkgSchedule startAutoPkgSchedule:start scheduleOrInterval:self.proposedSchedule isForced:force reply:^(NSError *error) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{

            BOOL currentlyScheduled = self.isCurrentlyScheduled;

            _scheduleMenuItem.state = currentlyScheduled;
            _scheduleEnabledBT.state = currentlyScheduled;
            [self updateIBOutletsWithSchedule:_currentSchedule];

            if (error) {
                // If error, reset the state to it's pre-modified status

                // If the authorization was canceled by user, don't present error.
                if (error.code != errAuthorizationCanceled) {
                    [self.progressDelegate stopProgress:error];
                }
            }
        }];
    }];
}



@end
