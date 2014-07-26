//
//  LGGitHubJSONLoader.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGGitHubJSONLoader.h"
#import "LGConstants.h"

@implementation LGGitHubJSONLoader

- (NSArray *)getAutoPkgReleasesJSON:(NSURL *)url
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
        NSLog(@"NSURLConnection error when attempting to get the latest AutoPkg releases from the GitHub API. Error: %@.", error);
    }

    // Create an array from the JSON data
    NSArray *releases = [[NSArray alloc] initWithArray:[NSJSONSerialization JSONObjectWithData:reqData options:NSJSONReadingMutableContainers error:&error]];

    if (error) {
        NSLog(@"NSJSONSerialization error when attempting to serialize JSON data from the GitHub API: Error: %@.", error);
    }
    
    return releases;
}

- (NSDictionary *)getLatestAutoPkgReleaseDictionary
{
    // Get the JSON data
    NSArray *releasesArray = [self getAutoPkgReleasesJSON:[NSURL URLWithString:kAutoPkgReleasesJSONURL]];

    // GitHub returns the latest release from the API at index 0
    NSDictionary *latestVersionDict = [releasesArray objectAtIndex:0];

    return latestVersionDict;
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

    // Get the "assets" from the dictionary
    NSDictionary *assets = [[latestVersionDict objectForKey:@"assets"] objectAtIndex:0];

    // Get the AutoPkg PKG download URL
    NSString *browserDownloadURL = [assets objectForKey:@"browser_download_url"];

    return browserDownloadURL;
}

@end
