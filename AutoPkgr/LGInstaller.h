//
//  LGInstaller.h
//  AutoPkgr
//
//  Created by Eldon on 9/9/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
 *  Install JSSImporter
 *
 *  @param reply block that is executed upon completion that takes one argument NSError
 */
- (void)installJSSImporter:(void (^)(NSError *error))reply;

@end
