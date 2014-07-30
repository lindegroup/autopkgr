//
//  LGEmailer.h
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>
#import "LGConstants.h"

@interface LGEmailer : NSObject

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message;
- (void)sendTestEmail;

@end
