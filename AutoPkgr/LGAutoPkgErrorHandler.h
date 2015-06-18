//
//  LGAutoPkgErrorHandler.h
//
//  Created by Eldon Ahrold on 4/23/15.
//
//  Copyright 2015 Eldon Ahrold
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

NSString *LGAutoPkgLocalizedString(NSString *key, NSString *comment);

/* AutoPkg Task Verbs
 */

typedef NS_ENUM(NSInteger, LGAutoPkgErrorCodes) {
    kLGAutoPkgErrorSuccess = 0,
    kLGAutoPkgErrorNoRecipes = 255,

    kLGAutoPkgErrorRepoModification = -2,
    kLGAutoPkgErrorNeedsRepair = -1
};

typedef NS_OPTIONS(NSInteger, LGAutoPkgVerb) {
    kLGAutoPkgUndefinedVerb = 0,
    // recipe verbs
    kLGAutoPkgRun = 1 << 0,
    kLGAutoPkgListRecipes = 1 << 1,
    kLGAutoPkgMakeOverride = 1 << 2,
    kLGAutoPkgSearch = 1 << 3,
    kLGAutoPkgInfo = 1 << 4,

    // repo verbs
    kLGAutoPkgRepoAdd = 1 << 10,
    kLGAutoPkgRepoDelete = 1 << 11,
    kLGAutoPkgRepoUpdate = 1 << 12,
    kLGAutoPkgRepoList = 1 << 13,

    // processor verbs
    kLGAutoPkgProcessorInfo = 1 << 20,
    kLGAutoPkgListProcessors = 1 << 21,

    // other verbs
    kLGAutoPkgVersion = 1 << 30,
};

@interface LGAutoPkgErrorHandler : NSObject

@property (nonatomic, readonly) NSPipe *pipe;
@property (nonatomic, readonly) NSString *errorString;

- (instancetype)initWithVerb:(LGAutoPkgVerb)verb;
- (NSError *)errorWithExitCode:(NSInteger)exitCode;

@end
