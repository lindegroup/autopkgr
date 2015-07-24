//
//  LGMenuItems.m
//  AutoPkgr
//
//  Created by Eldon on 7/23/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGMenuItems.h"

@implementation LGZeroMenuItem {
    NSView *_zeroView;
}

- (void)awakeFromNib
{
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [super awakeFromNib];
}

- (BOOL)isEnabled {
    return NO;
}

@end
