//
//  NSDateComponents+AHLaunchCtlSchedule.h
//  AHLaunchCtl
//
//  Created by Eldon on 4/26/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSInteger AHUndefinedSchedulComponent;

@interface AHLaunchJobSchedule : NSDateComponents
- (NSDictionary*)dictionary;

/**
 *  Set up a custom AHLaunchCtl Schedule
 *  @discussion Pass AHUndefinedSchedulComponent to any unused parameter.
 *
 *  @param minute  minuet of the hour
 *  @param hour    hour of the day
 *  @param day     day of the month
 *  @param weekday day of the week (0 is sunday)
 *  @param month   month of the year
 *
 *  @return Initialized AHLaunchJobSchedule object
 */
+ (instancetype)scheduleWithMinute:(NSInteger)minute
                              hour:(NSInteger)hour
                               day:(NSInteger)day
                           weekday:(NSInteger)weekday
                             month:(NSInteger)month;
/**
 *  setup a daily run
 *
 *  @param hour   hour of the day
 *  @param minute minute of the hour
 *
 *  @return Initialized AHLaunchJobSchedule object
 */
+ (instancetype)dailyRunAtHour:(NSInteger)hour minute:(NSInteger)minute;

/**
 *  setup a weekly run
 *
 *  @param weekday day of the week (0 is sunday)
 *  @param hour    hour of the day
 *
 *  @return Initialized AHLaunchJobSchedule object
 */
+ (instancetype)weeklyRunOnWeekday:(NSInteger)weekday hour:(NSInteger)hour;

/**
 *  setup a monthly run
 *
 *  @param day  day of the month
 *  @param hour hour of the day
 *
 *  @return Initialized AHLaunchJobSchedule object
 */
+ (instancetype)monthlyRunOnDay:(NSInteger)day hour:(NSInteger)hour;

@end
