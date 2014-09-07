//
//  LGAutoPkgSchedule.h
//  AutoPkgr
//
//  Created by Eldon on 9/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGProgressDelegate.h"

@interface LGAutoPkgSchedule : NSObject

@property (weak) id<LGProgressDelegate>progressDelegate;

+ (LGAutoPkgSchedule *)sharedTimer;
- (void)configure;
@end
