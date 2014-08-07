//
//  LGAutoPkgrProtocol.h
//  AutoPkgr
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGConstants.h"
#import "LGAutoPkgrAuthorizer.h"

@protocol HelperAgent <NSObject>
- (void)scheduleRun:(NSInteger)interval
               user:(NSString *)user
            program:(NSString *)program
              reply:(void (^)(NSError *error))reply;

- (void)removeScheduleWithReply:(void (^)(NSError *error))reply;

- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;

- (void)addPassword:(NSString *)password
            forUser:(NSString *)user
        andAutoPkgr:(NSString *)autoPkgrLaunchPath
              reply:(void (^)(NSError *error))reply;

- (void)quitHelper:(void (^)(BOOL success))reply;
- (void)uninstall:(void (^)(NSError *))reply;
@end
