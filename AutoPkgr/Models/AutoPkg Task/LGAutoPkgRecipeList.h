//
//  LGAutoPkgRecipeList.h
//  AutoPkgr
//
//  Created by Eldon on 11/5/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGAutoPkgRecipeList : NSObject

@property (copy) NSString *currentListName;
@property (copy, readonly) NSString *currentListPath;

@property (copy, readonly) NSArray *recipeLists;

- (BOOL)addRecipeList:(NSString *)list error:(NSError **)error;
- (BOOL)removeRecipeList:(NSString *)list error:(NSError **)error;

@end
