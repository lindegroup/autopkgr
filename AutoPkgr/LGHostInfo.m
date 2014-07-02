//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGHostInfo.h"

@implementation LGHostInfo

- (NSString *)getUserName
{
    return NSUserName();
}

- (NSString *)getHostName
{
    return [[NSHost currentHost] name];
}

- (NSString *)getUserAtHostName
{
    NSString *userAtHostName = [NSString stringWithFormat:@"%@@%@", [self getUserName], [self getHostName]];

    return userAtHostName;
}

@end
