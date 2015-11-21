//
//  LGAutoPkgrHelperConnection.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 7/28/14.
//  Copyright 2015 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import <Foundation/Foundation.h>
#import "LGAutoPkgrProtocol.h"
#import "LGProgressDelegate.h"

@interface LGAutoPkgrHelperConnection : NSObject

- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)delegate;

//@property (copy, nonatomic) void (^proxyErrorHandler)(NSError *);

/**
 *  @return proxy connection to Priviledged Helper
 */
@property (copy, nonatomic, readonly) id<AutoPkgrHelperAgent>remoteObjectProxy;

/**
 *  @return proxy connection to the Priviledged Helper plus error handler block
 */
- (id<AutoPkgrHelperAgent>)connectionError:(void (^)(NSError *error))handler;

- (void)closeConnection;

@end
