//
//  LGStatusImage.m
//  AutoPkgr
//
//  Created by Eldon on 10/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "NSImage+statusLight.h"

@implementation NSImage (installStatus)

+(instancetype)LGStatusAvaliable
{
    return [self imageNamed:@"NSStatusAvailable"];
}

+(instancetype)LGStatusPartiallyAvaliable
{
    return [self imageNamed:@"NSStatusPartiallyAvailable"];
}

+(instancetype)LGStatusUnavaliable
{
    return [self imageNamed:@"NSStatusUnavailable"];
}

+(instancetype)LGStatusNone
{
    return [self imageNamed:@"NSStatusNone"];

}

+(instancetype)LGStatusUpToDate
{
    return [self LGStatusAvaliable];
}

+(instancetype)LGStatusNotInstalled
{
    return [self LGStatusUnavaliable];
}

+(instancetype)LGStatusUpdateAvaliable{
    return [self LGStatusPartiallyAvaliable];
}

+(instancetype)LGStatusUnknown
{
    return [self LGStatusNone];
}

@end
