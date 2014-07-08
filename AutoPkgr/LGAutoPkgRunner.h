//
//  LGAutoPkgRunner.h
//  AutoPkgr
//
//  Created by James Barclay on 7/1/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGAutoPkgRunner : NSObject

- (NSArray *)getLocalAutoPkgRecipes;
- (NSArray *)getLocalAutoPkgRecipeRepos;
- (void)addAutoPkgRecipeRepo:(NSString *)repoURL;
- (void)removeAutoPkgRecipeRepo:(NSString *)repoURL;

@end
