//
//  LGGitHubRelease.m
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGGitHubRelease.h"

@implementation LGGitHubRelease

- (id)initWithJSONDictionary:(NSDictionary *)jsonDictionary
{
    if (self = [self init]) {
        _tagName = [jsonDictionary objectForKey:@"tag_name"];
        _zipBallURL = [jsonDictionary objectForKey:@"zipball_url"];
    }

    return self;
}

@end
