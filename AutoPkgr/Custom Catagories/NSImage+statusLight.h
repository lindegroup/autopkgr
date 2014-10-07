//
//  LGStatusImage.h
//  AutoPkgr
//
//  Created by Eldon on 10/6/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (statusLight)
+(instancetype)LGStatusAvaliable;
+(instancetype)LGStatusPartiallyAvaliable;
+(instancetype)LGStatusUnavaliable;
+(instancetype)LGStatusNone;

+(instancetype)LGStatusNotInstalled;
+(instancetype)LGStatusUpToDate;
+(instancetype)LGStatusUpdateAvaliable;
+(instancetype)LGStatusUnknown;
@end
