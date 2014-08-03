//
//  main.m
//  AutoPkgr
//
//  Created by James Barclay on 6/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LGAutoPkgRunner.h"

int main(int argc, const char * argv[])
{
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    
    if([args boolForKey:@"runInBackground"]){
        LGAutoPkgRunner *autoPkgRunner = [[LGAutoPkgRunner alloc] init];
        [autoPkgRunner runAutoPkgWithRecipeList];        
        while (autoPkgRunner.emailer && !autoPkgRunner.emailer.complete)
        {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
    }
    else{
        return NSApplicationMain(argc, argv);
    }
}
