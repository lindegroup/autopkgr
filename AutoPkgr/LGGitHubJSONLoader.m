//
//  LGGitHubJSONLoader.m
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

#import "LGGitHubJSONLoader.h"
#import "LGConstants.h"
#import "LGAutoPkgr.h"

#import <AFNetworking/AFNetworking.h>

@interface LGGitHubReleaseInfo()
@property (copy, nonatomic) NSString *repoURL;
@property (copy, nonatomic, readwrite) NSArray *jsonObject;
@property (copy, nonatomic, readwrite) NSDictionary *latestReleaseDictionary;
@property (copy, nonatomic, readwrite) NSArray *assets;

@property (copy, nonatomic, readwrite) NSString *latestVersion;
@property (copy, nonatomic, readwrite) NSString *latestReleaseDownload;
@property (copy, nonatomic, readwrite) NSArray *latestReleaseDownloads;
@end

@implementation LGGitHubReleaseInfo

- (instancetype)initWithURL:(NSString *)url {
    if (self = [super init]) {
        _repoURL = url;
    }
    return self;
}

- (instancetype)initWithJSON:(NSArray *)json {
    if (self = [super init]) {
        _jsonObject = json;
    }
    return self;
}

- (NSArray *)jsonObject {
    if (!_jsonObject && _repoURL) {
        // this is a backup synchronous method to pull the information.
        _jsonObject = [LGGitHubJSONLoader getJSONFromURL:_repoURL];
    }
    return _jsonObject;
}

- (NSDictionary *)latestReleaseDictionary
{
    if (!_latestReleaseDictionary) {
        _latestReleaseDictionary = [self.jsonObject firstObject];
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
    if(! _latestReleaseDownloads){
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

-(instancetype)initWithGitHubURL:(NSString *)gitHubURL {
    if (self = [super init]) {
        _gitHubURL = gitHubURL;
    }
    return self;
}

- (void)getReleaseInfo:(void (^)(LGGitHubReleaseInfo *, NSError *error))complete {

    NSURL *url = [NSURL URLWithString:_gitHubURL];

    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:15.0];

    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:req];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, NSArray * responseObject) {
        LGGitHubReleaseInfo *info = [[LGGitHubReleaseInfo alloc] initWithJSON:responseObject];
        complete(info, nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        complete(nil, error);
    }];

    [operation start];
}


+ (NSArray *)getJSONFromURL:(NSString *)aUrl
{
    NSURL *url = [NSURL URLWithString:aUrl];

    // Create the NSURLRequest object with the given URL
    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                     timeoutInterval:15.0];

    // Initialize our response and error objects
    NSURLResponse *resp;
    NSError *error = nil;

    // Get the JSON data
    NSData *reqData = [NSURLConnection sendSynchronousRequest:req
                                            returningResponse:&resp
                                                        error:&error];

    if (error) {
        NSLog(@"NSURLConnection error when attempting to get JSON data from the GitHub API. Error: %@.", error);
        return nil;
    }

    if (reqData != nil) {
        // Initialize our error object
        NSError *error = nil;

        // get the JSON object out of the data
        id jsonObject = [NSJSONSerialization JSONObjectWithData:reqData options:NSJSONReadingMutableContainers error:&error];

        // Check that the object is an array, and if so return it
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
    // Assign the keys we'll be using
    NSString *cloneURL = @"clone_url";
    NSString *fullName = @"full_name";
    NSString *stargazersCount = @"stargazers_count";

    // Get the JSON data
    NSArray *reposArray = [self getJSONFromURL:kLGAutoPkgRepositoriesJSONURL];
    
    NSMutableArray *mutableArray = [[NSMutableArray alloc] init];

    for (NSDictionary *dct in reposArray) {
        // Create a mutable dictionary for our repo and star count
        NSMutableDictionary *mutableDict = [[NSMutableDictionary alloc] init];

        // Skip adding the clone URL and stargazers count if it's not a recipe repo
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
