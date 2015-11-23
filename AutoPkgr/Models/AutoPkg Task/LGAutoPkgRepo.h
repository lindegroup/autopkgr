//
//  LGAutoPkgRepo.h
//  AutoPkgr
//
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

typedef NS_ENUM(OSStatus, LGAutoPkgRepoStatus) {
    kLGAutoPkgRepoNotInstalled = 1 << 0,
    kLGAutoPkgRepoUpdateAvailable = 1 << 1,
    kLGAutoPkgRepoUpToDate = 1 << 2,
};

@interface LGAutoPkgRepo : NSObject

- (instancetype)init __unavailable;

@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *path;
@property (copy, nonatomic, readonly) NSURL *cloneURL;

@property (copy, nonatomic, readonly) NSURL *homeURL;
@property (copy, nonatomic, readonly) NSURL *commitsURL;

@property (copy, nonatomic, readonly) NSString *defaultBranch;

@property (assign, nonatomic, readonly) NSInteger stars;

@property (assign, nonatomic, readonly) BOOL isInstalled;
@property (assign, nonatomic, readonly) BOOL isAheadOfMaster;

@property (assign, nonatomic, readonly) LGAutoPkgRepoStatus status;
@property (copy) void (^statusChangeBlock)(LGAutoPkgRepoStatus);

/**
 *  Initialize a repo with a clone url
 *
 *  @param cloneURL clone URL
 *
 *  @return initialized AutoPkgRepo Object
 */
- (instancetype)initWithCloneURL:(NSString *)cloneURL;

/**
 *  Check if there are updates available for the repo.
 *
 *  @param sender Object sending the message. If the sender is set to nil, it will only refresh every 5-10 minuets. You should set this to nil if using in a table view.
 */
- (IBAction)checkRepoStatus:(id)sender;
- (void)getRepoStatus:(void (^)(LGAutoPkgRepoStatus status))reply;

- (void)install:(void (^)(NSError *))reply;
- (void)remove:(void (^)(NSError *))reply;

/**
 *  Update the repo;
 *
 *  @param reply block executed upon completion.
 */
- (void)update:(void (^)(NSError *error))reply;

/**
 *  Open the GitHub commit page for the repo.
 *
 *  @param sender IBOutlet or object.
 */
- (void)viewCommitsOnGitHub:(id)sender;

/**
 *  Get an array of installed repos and repos hosted on autopkg's github page.
 *
 *  @param reply block object that takes one parameter, an array of LGAutoPkgRepo Ojbects.
 */
+ (void)commonRepos:(void (^)(NSArray *repos))reply;

@end
