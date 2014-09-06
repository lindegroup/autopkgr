//
//  LGAutoPkgSchedule.m
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgSchedule.h"
#import "LGAutoPkgr.h"
#import "LGAutoPkgTask.h"
#import "LGApplications.h"
#import "LGEmailer.h"

@implementation LGAutoPkgSchedule{
    NSTimer *_timer;
}
-(void)startTimer
{
    NSLog(@"starting timer");
    LGDefaults *defaults = [[LGDefaults alloc]init];
    
    if ([defaults integerForKey:kLGAutoPkgRunInterval]) {
        double i = [defaults integerForKey:kLGAutoPkgRunInterval];
        if (i != 0) {
            NSTimeInterval ti = i * 60 * 60; // Convert hours to seconds for our time interval
            _timer = [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(runAutoPkg) userInfo:nil repeats:YES];
        } else {
            NSLog(@"i is 0 because that's what the user entered or what they entered wasn't a digit.");
        }
    } else {
        NSLog(@"The user enabled automatic checking for app updates but they specified no interval.");
    }
}

- (void)stopTimer{
    if ([_timer isValid]) {
        [_timer invalidate];
    }
    _timer = nil;
}

-(void)runAutoPkg{
    LGDefaults *defaults = [[LGDefaults alloc] init];
    if (defaults.checkForNewVersionsOfAppsAutomaticallyEnabled) {
        NSLog(@"Beginning scheduled run of AutoPkg");
        
        NSString *recipeList = [LGApplications recipeList];
        
        [LGAutoPkgTask runRecipeList:recipeList
                            progress:^(NSString *message, double taskProgress) {
                                NSLog(@"%@",message);
                            }
                               reply:^(NSDictionary *report,NSError *error) {
                                   LGEmailer *emailer = [LGEmailer new];
                                   [emailer sendEmailForReport:report error:error];
                               }];
    }else{
        [self stopTimer];
    }
}
@end
