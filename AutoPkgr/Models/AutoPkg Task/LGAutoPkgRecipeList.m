//
//  LGAutoPkgRecipeList.m
//  AutoPkgr
//
//  Created by Eldon on 11/5/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgRecipeList.h"
#import "LGAutoPkgr.h"

@implementation LGAutoPkgRecipeList {
    NSString *_appSupportDir;
    NSFileManager *_fm;

}

- (instancetype)init {
    if (self = [super init]){
        _appSupportDir = [LGHostInfo getAppSupportDirectory];
        _fm = [NSFileManager defaultManager];

    }
    return self;
}

- (NSString *)currentListPath {
    NSString *list = self.currentListName;
    if (_appSupportDir.length && list.length) {
        list = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
        BOOL isDir;
        if([_fm fileExistsAtPath:list isDirectory:&isDir] && !isDir){
            return list;
        }
    }
    return nil;
}

- (NSString *)currentListName
{
    NSString *list = [[NSUserDefaults standardUserDefaults] stringForKey:@"RecipeList"];
    NSString *check = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    BOOL isDir;
    if([_fm fileExistsAtPath:check isDirectory:&isDir] && !isDir){
        return list;
    } else {
        return @"recipe_list";
    }
}

- (void)setCurrentListName:(NSString *)currentListName {
    [[NSUserDefaults standardUserDefaults] setValue:currentListName forKey:@"RecipeList"];
}

- (NSArray *)recipeLists {
    NSArray *recipeLists = [NSFileManager.defaultManager
                                   contentsOfDirectoryAtPath:_appSupportDir
                                   error:nil];

    NSPredicate *pathExtension = [NSPredicate predicateWithFormat:@"pathExtension == 'txt'"];

    return [[recipeLists filteredArrayUsingPredicate:pathExtension] mapObjectsUsingBlock:^id(NSString *obj, NSUInteger idx) {
        return obj.stringByDeletingPathExtension;
    }];
}

- (BOOL)addRecipeList:(NSString *)list error:(NSError *__autoreleasing *)error {
    NSString *recipeList = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    if (access(recipeList.UTF8String, F_OK)) {
        NSString *header = quick_formatString(@"# AutoPkg %@ Recipe List #", list );
        return [header writeToFile:recipeList atomically:YES encoding:NSUTF8StringEncoding error:error];
    } else {
        return [LGError errorWithCode:kLGErrorRecipeListFileAccess error:error];
    }
}

- (BOOL)removeRecipeList:(NSString *)list error:(NSError *__autoreleasing *)error {
    NSString *recipeList = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    if (access(recipeList.UTF8String, F_OK) == 0) {
        return [list isEqualToString:@"recipe_list"] ?
            YES : [_fm removeItemAtPath:recipeList error:error];
    } else {
        return [LGError errorWithCode:kLGErrorRecipeListFileAccess error:error];
    }
}

@end
