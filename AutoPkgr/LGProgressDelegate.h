//
//  LGProgressDelegate.h
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LGProgressDelegate <NSObject>
- (void)startProgressWithMessage:(NSString *)message;
- (void)stopProgress:(NSError *)error;
- (void)updateProgress:(NSString *)message progress:(double)progress;
@end
