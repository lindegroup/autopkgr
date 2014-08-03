//
//  main.m
//  helper
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGAutoPkgrHelper.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        LGAutoPkgrHelper *helper = [LGAutoPkgrHelper new];
        [helper run];
    }
    return 0;
}

