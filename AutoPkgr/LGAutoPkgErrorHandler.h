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

/* AutoPkg Task Verbs
 */
typedef NS_ENUM(NSInteger, LGAutoPkgVerb) {
    kLGAutoPkgUndefinedVerb,
    // recipe verbs
    kLGAutoPkgRun,
    kLGAutoPkgRecipeList,
    kLGAutoPkgMakeOverride,
    kLGAutoPkgSearch,

    // repo verbs
    kLGAutoPkgRepoAdd,
    kLGAutoPkgRepoDelete,
    kLGAutoPkgRepoUpdate,
    kLGAutoPkgRepoList,

    // other verbs
    kLGAutoPkgVersion,
};

@interface LGAutoPkgErrorHandler : NSObject

@property (nonatomic, readonly) NSPipe *pipe;
@property (nonatomic, readonly) NSString *errorString;

- (instancetype)initWithVerb:(LGAutoPkgVerb)verb;
- (NSError *)errorWithExitCode:(NSInteger)exitCode;

@end
