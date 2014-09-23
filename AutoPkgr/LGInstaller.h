//
//  LGInstaller.h
//  AutoPkgr
//
//  Created by Eldon on 9/9/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGProgressDelegate.h"

@interface LGInstaller : NSObject

@property (weak) NSWindow *modalWindow;
@property (weak) id<LGProgressDelegate> progressDelegate;

#pragma mark - Async Methods
/**
 *  Install supported Git from github release page
 *
 *  @param reply block that is executed upon completion that takes one argument NSError
 */
- (void)installGit:(void (^)(NSError *error))reply;

/**
 *  Install AutoPkg from github release page
 *
 *  @param reply block that is executed upon completion that takes one argument NSError
 */
- (void)installAutoPkg:(void (^)(NSError *error))reply;

/**
 *  Update AutoPkgr
 *
 *  @param reply block that is executed upon completion that takes one argument NSError
 */
// - (void)updateAutoPkgr:(void (^)(NSError* error))reply;

#pragma mark - Blocking Methdos
- (BOOL)runGitInstaller:(NSError **)error;
- (BOOL)runAutoPkgInstaller:(NSError **)error;

@end
