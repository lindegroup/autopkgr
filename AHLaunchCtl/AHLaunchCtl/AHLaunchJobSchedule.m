//
//  NSDateComponents+AHLaunchCtlSchedule.m
//  AHLaunchCtl
//
//  Created by Eldon on 4/26/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "AHLaunchJobSchedule.h"
NSInteger AHUndefinedSchedulComponent = NSUndefinedDateComponent;

@implementation AHLaunchJobSchedule

- (NSDictionary*)dictionary
{
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithCapacity:5];
    if (self.minute != AHUndefinedSchedulComponent)
        [dict setObject:[NSNumber numberWithInteger:self.minute] forKey:@"Minute"];
    if (self.hour != AHUndefinedSchedulComponent)
        [dict setObject:[NSNumber numberWithInteger:self.hour] forKey:@"Hour"];
    if (self.day != AHUndefinedSchedulComponent)
        [dict setObject:[NSNumber numberWithInteger:self.day] forKey:@"Day"];
    if (self.weekday != AHUndefinedSchedulComponent)
        [dict setObject:[NSNumber numberWithInteger:self.weekday]
                 forKey:@"Weekday"];
    if (self.month != AHUndefinedSchedulComponent)
        [dict setObject:[NSNumber numberWithInteger:self.month] forKey:@"Weekday"];

    return [NSDictionary dictionaryWithDictionary:dict];
}

+ (instancetype)scheduleWithMinute:(NSInteger)minute
                              hour:(NSInteger)hour
                               day:(NSInteger)day
                           weekday:(NSInteger)weekday
                             month:(NSInteger)month
{
    AHLaunchJobSchedule* components = [AHLaunchJobSchedule new];

    if (minute != AHUndefinedSchedulComponent) {
        components.minute = minute;
    }
    if (hour != AHUndefinedSchedulComponent) {
        components.hour = hour;
    }
    if (day != AHUndefinedSchedulComponent) {
        components.day = day;
    }
    if (weekday != AHUndefinedSchedulComponent) {
        components.weekday = weekday;
    }
    if (month != AHUndefinedSchedulComponent) {
        components.month = month;
    }
    return components;
}

+ (instancetype)dailyRunAtHour:(NSInteger)hour minute:(NSInteger)minute
{
    return [self scheduleWithMinute:minute
                               hour:hour
                                day:AHUndefinedSchedulComponent
                            weekday:AHUndefinedSchedulComponent
                              month:AHUndefinedSchedulComponent];
}
+ (instancetype)weeklyRunOnWeekday:(NSInteger)weekday hour:(NSInteger)hour
{
    return [self scheduleWithMinute:00
                               hour:hour
                                day:AHUndefinedSchedulComponent
                            weekday:weekday
                              month:AHUndefinedSchedulComponent];
}

+ (instancetype)monthlyRunOnDay:(NSInteger)day hour:(NSInteger)hour
{
    return [self scheduleWithMinute:00
                               hour:hour
                                day:day
                            weekday:AHUndefinedSchedulComponent
                              month:AHUndefinedSchedulComponent];
}

@end
