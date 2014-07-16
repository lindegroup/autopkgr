//
//  LGChangeHandler.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/15/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGChangeHandler.h"

@implementation LGChangeHandler

- (id)init
{
    self = [super init];
    
    defaults = [NSUserDefaults standardUserDefaults];
    
    return self;
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    id object = [notification object];
    
    if ([object isEqual:_smtpServer]) {
        [defaults setObject:[_smtpServer stringValue] forKey:kSMTPServer];
    }
    
    // Synchronize with the defaults database
    [defaults synchronize];
}


@end
