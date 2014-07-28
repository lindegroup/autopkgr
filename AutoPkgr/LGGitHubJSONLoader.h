//
//  LGGitHubJSONLoader.h
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGGitHubJSONLoader : NSObject

- (NSArray *)getAutoPkgReleasesJSON:(NSURL *)url;
- (NSDictionary *)getLatestAutoPkgReleaseDictionary;
- (NSString *)getLatestAutoPkgReleaseVersionNumber;
- (NSString *)getLatestAutoPkgDownloadURL;

@end
