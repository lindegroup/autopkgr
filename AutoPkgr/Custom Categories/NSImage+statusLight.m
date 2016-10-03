//
//  NSImage+statusLight.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 10/6/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "NSImage+statusLight.h"

@implementation NSImage (installStatus)

+ (instancetype)LGNoImage
{
    static id image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self new];
    });
    return image;
}

+ (instancetype)LGCaution
{
    static id image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        image = [self imageNamed:@"NSCaution"];
        ;
    });
    return image;
}

+ (instancetype)LGStatusAvailable
{
    return [self imageNamed:@"NSStatusAvailable"];
}

+ (instancetype)LGStatusPartiallyAvailable
{
    return [self imageNamed:@"NSStatusPartiallyAvailable"];
}

+ (instancetype)LGStatusUnavailable
{
    return [self imageNamed:@"NSStatusUnavailable"];
}

+ (instancetype)LGStatusNone
{
    return [self imageNamed:@"NSStatusNone"];
}

+ (instancetype)LGStatusUpToDate
{
    return [self LGStatusAvailable];
}

+ (instancetype)LGStatusNotInstalled
{
    return [self LGStatusUnavailable];
}

+ (instancetype)LGStatusUpdateAvailable
{
    return [self LGStatusPartiallyAvailable];
}

+ (instancetype)LGStatusUnknown
{
    return [self LGStatusNone];
}

@end
