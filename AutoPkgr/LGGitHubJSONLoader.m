//
//  LGGitHubJSONLoader.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

@implementation LGGitHubJSONLoader

- (NSData *)getJSONFromURL:(NSURL *)url
{
    // Create the NSURLRequest object with the given URL
    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
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

    return reqData;
}

- (NSArray *)getArrayFromJSONData:(NSData *)reqData
{
    if (reqData != nil) {
        // Initialize our error object
        NSError *error = nil;

        // Create an array from the JSON data
        NSArray *arr = [[NSArray alloc] initWithArray:[NSJSONSerialization JSONObjectWithData:reqData options:NSJSONReadingMutableContainers error:&error]];

        if (error) {
            NSLog(@"NSJSONSerialization error when attempting to serialize JSON data from the GitHub API: Error: %@.", error);
            return nil;
        }

        return arr;
    }

    return nil;
}

- (NSDictionary *)getLatestAutoPkgReleaseDictionary
{
    // Get the JSON data
    NSArray *releasesArray = [self getArrayFromJSONData:[self getJSONFromURL:[NSURL URLWithString:kAutoPkgReleasesJSONURL]]];

    // GitHub returns the latest release from the API at index 0
    NSDictionary *latestVersionDict = [releasesArray objectAtIndex:0];

    return latestVersionDict;
}

- (NSArray *)getAutoPkgRecipeRepos
{
    // Assign the keys we'll be using
    NSString *cloneURL = @"clone_url";
    NSString *fullName = @"full_name";
    NSString *stargazersCount = @"stargazers_count";

    // Get the JSON data
    NSArray *reposArray = [self getArrayFromJSONData:[self getJSONFromURL:[NSURL URLWithString:kAutoPkgRepositoriesJSONURL]]];
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

- (NSString *)getLatestAutoPkgReleaseVersionNumber
{
    // Get an NSDictionary of the latest release JSON
    NSDictionary *latestVersionDict = [self getLatestAutoPkgReleaseDictionary];

    // AutoPkg version numbers are prepended with "v"
    // Let's remove that from our version string
    NSString *latestVersionNumber = [[latestVersionDict objectForKey:@"tag_name"] stringByReplacingOccurrencesOfString:@"v" withString:@""];
    NSLog(@"Latest version of AutoPkg available on GitHub: %@.", latestVersionNumber);

    return latestVersionNumber;
}

- (NSString *)getLatestAutoPkgDownloadURL
{
    // Get an NSDictionary of the latest release JSON
    NSDictionary *latestVersionDict = [self getLatestAutoPkgReleaseDictionary];

    // Get the AutoPkg PKG download URL
    NSString *browserDownloadURL = [[[latestVersionDict objectForKey:@"assets"] objectAtIndex:0] objectForKey:@"browser_download_url"];

    return browserDownloadURL;
}

@end
