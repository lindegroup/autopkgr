//
//  LGGitHubRelease.h
//  AutoPkgr
//
//  Created by James Barclay on 7/18/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGGitHubRelease : NSObject

- (id)initWithJSONDictionary:(NSDictionary *)jsonDictionary;

@property (readonly) NSString *tagName;
@property (readonly) NSString *zipBallURL;

@end
