//
//  LGGitHubJSONLoader.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGGitHubJSONLoader.h"
#import "LGGitHubRelease.h"

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

    if (error ) {
        NSLog(@"NSJSONSerialization error when attempting to serialize JSON data from the GitHub API: Error: %@.", error);
    }

    // Create a mutable array to hold releases
    NSMutableArray *mutableReleases = [[NSMutableArray alloc] init];

    for (NSDictionary *dct in releases) {
        // Create a new LGGitHubRelease object
        // and initialize it with info from
        // the dictionary
        LGGitHubRelease *release = [[LGGitHubRelease alloc] initWithJSONDictionary:dct];
        // Add the LGGitHubRelease object to the
        // mutable array
        [mutableReleases addObject:release];
    }
    
    return [NSArray arrayWithArray:mutableReleases];
}

@end
