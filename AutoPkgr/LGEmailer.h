//
//  LGEmailer.h
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MailCore/MailCore.h>

@interface LGEmailer : NSObject

/*
 * complete observable property of current LGEmailer status
 * returns NO while in the process of sending and email, YES on complete or error 
 */
@property (nonatomic) BOOL complete;

- (void)sendEmailNotification:(NSString *)subject message:(NSString *)message;
- (void)sendTestEmail;

@end
