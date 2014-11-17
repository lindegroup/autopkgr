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
#pragma mark - Schedule
#pragma mark-- Add
- (void)scheduleRun:(NSInteger)interval
               user:(NSString *)user
            program:(NSString *)program
      authorization:(NSData *)authData
              reply:(void (^)(NSError *error))reply;


#pragma mark-- Remove
- (void)removeScheduleWithAuthorization:(NSData *)authData
                                  reply:(void (^)(NSError *error))reply;

#pragma mark - Install Package
- (void)installPackageFromPath:(NSString *)path
                 authorization:(NSData *)authData
                         reply:(void (^)(NSError *error))reply;

#pragma mark - Keycahin Password
#pragma mark-- Add

- (void)addPassword:(NSString *)password
            forUser:(NSString *)user
        andAutoPkgr:(NSString *)autoPkgrLaunchPath
              reply:(void (^)(NSError *error))reply;

#pragma mark-- Remove
- (void)removePassword:(NSString *)password
               forUser:(NSString *)user
                 reply:(void (^)(NSError *error))reply;

#pragma mark - Life Cycle
- (void)quitHelper:(void (^)(BOOL success))reply;
- (void)uninstall:(NSData *)authData reply:(void (^)(NSError *))reply;

@end
