//
//  LGGitHubJSONLoader.h
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
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

@interface LGGitHubReleaseInfo : NSObject

- (instancetype)init __unavailable;
- (instancetype)initWithURL:(NSString *)gitHubURL;


@property (copy, nonatomic, readonly) NSString *latestVersion;
@property (copy, nonatomic, readonly) NSString *latestReleaseDownload;
@property (copy, nonatomic, readonly) NSArray *latestReleaseDownloads;

/**
 *  Whether the info object's init time has outlived it's lifeSpan.
 */
@property (assign, nonatomic, readonly) BOOL isExpired;
/**
 *  the interval of time before the validity the release info should be reloaded.
 */
@property (assign, nonatomic, readonly) NSTimeInterval lifespan;


@end

@interface LGGitHubJSONLoader : NSObject
- (instancetype)initWithGitHubURL:(NSString *)gitHubURL;
- (void)getReleaseInfo:(void (^)(LGGitHubReleaseInfo *info, NSError *error))info;

// Synchronously get raw data from GitHub URL
+ (NSArray *)getJSONFromURL:(NSString *)url;
+ (NSArray *)getAutoPkgRecipeRepos;

@end
