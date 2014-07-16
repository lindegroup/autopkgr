//
//  LGChangeHandler.h
//  AutoPkgr
//
//  Created by Josh Senick on 7/15/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGConstants.h"

@interface LGChangeHandler : NSObject <NSTextDelegate> {
    NSUserDefaults *defaults;
}

@property (weak) IBOutlet NSTextField *smtpServer;

@end
