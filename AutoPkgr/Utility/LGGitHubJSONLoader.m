//
//  LGGitHubJSONLoader.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "LGGitHubJSONLoader.h"
#import "LGConstants.h"
#import "LGAutoPkgr.h"

#import <AFNetworking/AFNetworking.h>

@interface LGGitHubReleaseInfo ()
@property (copy, nonatomic) NSString *repoURL;
@property (copy, nonatomic, readwrite) NSArray *jsonObject;
@property (copy, nonatomic, readwrite) NSDictionary *latestReleaseDictionary;
@property (copy, nonatomic, readwrite) NSArray *assets;

@property (copy, nonatomic, readwrite) NSString *latestVersion;
@property (copy, nonatomic, readwrite) NSString *latestReleaseDownload;
@property (copy, nonatomic, readwrite) NSArray *latestReleaseDownloads;
@end

@implementation LGGitHubReleaseInfo {
    NSDate *_infoRetrievedDate;
}

/**
 *  Private init method.
 *
 *  @return self;
 */
- (instancetype)init_
{
    if (self = [super init]) {
        _lifespan = 600;
    }
    return self;
}

- (instancetype)initWithURL:(NSString *)url
{
    if (self = [self init_]) {
        _repoURL = url;
    }
    return self;
}

- (instancetype)initWithJSON:(NSArray *)json
{
    if (self = [self init_]) {
        _jsonObject = json;
        _infoRetrievedDate = [NSDate date];
    }
    return self;
}

- (BOOL)isExpired
{
    if (_infoRetrievedDate == nil) {
        _infoRetrievedDate = [NSDate date];
        return YES;
    } else if (_lifespan <= -(_infoRetrievedDate.timeIntervalSinceNow)){
        return YES;
    }
    return NO;
}

- (NSArray *)jsonObject
{
    if (!_jsonObject && _repoURL) {
        // This is a backup synchronous method to pull the information.
        _jsonObject = [LGGitHubJSONLoader getJSONFromURL:_repoURL];
        _infoRetrievedDate = [NSDate date];
    }
    return _jsonObject;
}

- (NSDictionary *)latestReleaseDictionary
{
    if (!_latestReleaseDictionary) {
        [self.jsonObject enumerateObjectsUsingBlock:^(NSDictionary *releaseDict, NSUInteger idx, BOOL *stop) {
            NSNumber *prerelease = releaseDict[@"prerelease"];
            if (prerelease.boolValue == NO) {
                _latestReleaseDictionary = releaseDict;
                *stop = YES;
            } else {
                NSLog(@"Skipping prerelease version of %@", self.repoURL);
            }
        }];
    }
    return _latestReleaseDictionary;
}

- (NSString *)latestVersion
{
    if (!_latestVersion) {
        _latestVersion = [self.latestReleaseDictionary[@"tag_name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
    }
    return _latestVersion;
}

- (NSArray *)assets
{
    if (!_assets) {
        _assets = self.latestReleaseDictionary[@"assets"];
    }
    return _assets;
}

- (NSString *)latestReleaseDownload
{
    if (!_latestReleaseDownload) {
        _latestReleaseDownload = self.assets.firstObject[@"browser_download_url"];
    }
    return _latestReleaseDownload;
}

- (NSArray *)latestReleaseDownloads
{
    if (!_latestReleaseDownloads) {
        NSMutableArray *array = nil;
        for (NSDictionary *asset in self.assets)
            if (asset[@"browser_download_url"]) {
                if (!array) {
                    array = [[NSMutableArray alloc] init];
                };
                [array addObject:asset[@"browser_download_url"]];
            }
        _latestReleaseDownloads = [array copy];
    }

    return _latestReleaseDownloads;
}

@end

@implementation LGGitHubJSONLoader {
    NSString *_gitHubURL;
}

- (instancetype)initWithGitHubURL:(NSString *)gitHubURL
{
    if (self = [super init]) {
        _gitHubURL = gitHubURL;
    }
    return self;
}

- (void)getReleaseInfo:(void (^)(LGGitHubReleaseInfo *, NSError *error))complete
{

    NSURL *url = [NSURL URLWithString:_gitHubURL];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:15.0];
    
    if (_apiToken) {
        [req setValue:[@"token " stringByAppendingString:_apiToken] forHTTPHeaderField:@"Authorization"];
    };

    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
        LGGitHubReleaseInfo *info = [[LGGitHubReleaseInfo alloc] initWithJSON:responseObject];
        complete(info, nil);
//        DevLog(@"Remaining calls per hour to GitHub API: %@/%@ (used Cache = %@)",
//               operation.response.allHeaderFields[@"X-RateLimit-Remaining"],
//               operation.response.allHeaderFields[@"X-RateLimit-Limit"],
//               [operation.response.allHeaderFields[@"Status"] isEqualToString:@"304 Not Modified"] ? @"YES": @"NO");
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        complete(nil, error);
    }];

    [operation start];
}

+ (NSArray *)getJSONFromURL:(NSString *)aUrl
{
    NSURL *url = [NSURL URLWithString:aUrl];

    // Create the NSURLRequest object with the given URL.
    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:5.0];

    // Initialize our response and error objects.
    NSHTTPURLResponse *resp;
    NSError *error = nil;

    // Get the JSON data.
    NSData *reqData = [NSURLConnection sendSynchronousRequest:req
                                            returningResponse:&resp
                                                        error:&error];

    if (error || resp.statusCode != 200) {
        NSLog(@"NSURLConnection error when attempting to get JSON data from the GitHub API. Error: %@.", error);
        return nil;
    }

    if (reqData != nil) {
        // Initialize our error object.
        NSError *error = nil;

        // Get the JSON object out of the data.
        id jsonObject = [NSJSONSerialization JSONObjectWithData:reqData options:NSJSONReadingMutableContainers error:&error];

        // Check that the object is an array, and if so return it.
        if ([jsonObject isKindOfClass:[NSArray class]]) {
            return jsonObject;
        } else if (error) {
            NSLog(@"NSJSONSerialization error when attempting to serialize JSON data from the GitHub API: Error: %@.", error);
        }
    }
    return nil;
}

+ (NSArray *)getAutoPkgRecipeRepos
{
    // Assign the keys we'll be using.
    NSString *cloneURL = @"clone_url";
    NSString *fullName = @"full_name";
    NSString *stargazersCount = @"stargazers_count";

    // Get the JSON data.
    NSArray *reposArray = [self getJSONFromURL:kLGAutoPkgRepositoriesJSONURL];

    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];

    for (NSDictionary *dct in reposArray) {
        // Create a mutable dictionary for our repo and star count.
        NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] init];

        // Skip adding the clone URL and stargazers count if it's not a recipe repo in the AutoPkg organization.
        if ([[dct objectForKey:fullName] isEqual:@"autopkg/autopkg"]) {
            continue;
        }

        [mutableDict setObject:[dct objectForKey:cloneURL] forKey:cloneURL];
        [mutableDict setObject:[dct objectForKey:stargazersCount] forKey:stargazersCount];
        [mutableArray addObject:mutableDict];
    }

    if ([mutableArray count]) {
        NSSortDescriptor *stargazersCountDescriptor = [[NSSortDescriptor alloc]
            initWithKey:stargazersCount
              ascending:NO];
        NSArray *descriptors = [NSArray arrayWithObjects:stargazersCountDescriptor, nil];
        NSArray *sortedArrayOfDictionaries = [mutableArray sortedArrayUsingDescriptors:descriptors];

        NSMutableArray *sortedArrayOfRepos = [[NSMutableArray alloc] init];
        for (NSDictionary *sortedStarsAndRepos in sortedArrayOfDictionaries) {
            [sortedArrayOfRepos addObject:[sortedStarsAndRepos objectForKey:cloneURL]];
        }

        return [NSArray arrayWithArray:sortedArrayOfRepos];
    }

    return nil;
}

@end
