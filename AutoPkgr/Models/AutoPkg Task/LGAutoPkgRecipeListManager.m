//
//  LGAutoPkgRecipeListManager.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgRecipeListManager.h"
#import "LGAutoPkgr.h"

@implementation LGAutoPkgRecipeListManager {
    NSString *_appSupportDir;
    NSFileManager *_fm;
    dispatch_source_t _source;
}

@synthesize changeHandler = _changeHandler;

- (void)dealloc
{
    if (_source) {
        dispatch_source_cancel(_source);
    }
}
- (instancetype)init
{
    if (self = [super init]) {
        _appSupportDir = [LGHostInfo getAppSupportDirectory];
        _fm = [NSFileManager defaultManager];
    }
    return self;
}

- (NSString *)currentListPath
{
    NSString *list = self.currentListName;
    if (_appSupportDir.length && list.length) {
        list = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
        BOOL isDir;
        if ([_fm fileExistsAtPath:list isDirectory:&isDir] && !isDir) {
            return list;
        }
    }
    return quick_formatString(@"%@/recipe_list.txt", _appSupportDir);
}

- (NSString *)currentListName
{
    NSString *list = [[NSUserDefaults standardUserDefaults] stringForKey:@"RecipeList"];
    NSString *check = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    BOOL isDir;
    if ([_fm fileExistsAtPath:check isDirectory:&isDir] && !isDir) {
        return list;
    }
    else {
        return @"recipe_list";
    }
}

- (void)setCurrentListName:(NSString *)currentListName
{
    [[NSUserDefaults standardUserDefaults] setValue:currentListName forKey:@"RecipeList"];
}

- (NSArray *)recipeLists
{
    NSArray *recipeLists = [NSFileManager.defaultManager
        contentsOfDirectoryAtPath:_appSupportDir
                            error:nil];

    NSPredicate *pathExtensionPredicate = [NSPredicate predicateWithFormat:@"pathExtension == 'txt'"];

    NSArray *lists = [[recipeLists filteredArrayUsingPredicate:pathExtensionPredicate]
        mapObjectsUsingBlock:^id(NSString *obj, NSUInteger idx) {
            return obj.stringByDeletingPathExtension;
        }];

    return lists.count ? lists : @[ @"recipe_list" ];
}

- (BOOL)addRecipeList:(NSString *)list error:(NSError *__autoreleasing *)error
{
    NSString *recipeList = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    if (access(recipeList.UTF8String, F_OK)) {
        if ([@"" writeToFile:recipeList atomically:YES encoding:NSUTF8StringEncoding error:error]) {
            self.currentListName = list;
            return YES;
        }
        return NO;
    }
    else {
        return [LGError errorWithCode:kLGErrorRecipeListFileAccess error:error];
    }
}

- (BOOL)removeRecipeList:(NSString *)list error:(NSError *__autoreleasing *)error
{
    NSString *recipeList = quick_formatString(@"%@/%@.txt", _appSupportDir, list);
    if (access(recipeList.UTF8String, F_OK) == 0) {
        return [list isEqualToString:@"recipe_list"] ? YES : [_fm removeItemAtPath:recipeList error:error];
    }
    else {
        return [LGError errorWithCode:kLGErrorRecipeListFileAccess error:error];
    }
}

- (void (^)(NSArray *))changeHandler
{
    return _changeHandler;
}

- (void)setChangeHandler:(void (^)(NSArray *))changeHandler
{
    _changeHandler = changeHandler;
    NSString *path = _appSupportDir;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    int fd = open(path.UTF8String, O_EVTONLY);

    unsigned long mask = DISPATCH_VNODE_DELETE | DISPATCH_VNODE_WRITE | DISPATCH_VNODE_EXTEND | DISPATCH_VNODE_ATTRIB | DISPATCH_VNODE_LINK | DISPATCH_VNODE_RENAME | DISPATCH_VNODE_REVOKE;

    _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_VNODE, fd,
                                     mask, queue);

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_source, ^{
        // Run query for all events.
        if (changeHandler) {
            changeHandler(weakSelf.recipeLists);
        }
        unsigned long flags = dispatch_source_get_data(_source);
        if (flags & DISPATCH_VNODE_DELETE) {
            // Restart event if file was deleted.
            dispatch_source_cancel(_source);
        }
    });

    dispatch_source_set_cancel_handler(_source, ^(void) {
        close(fd);
    });

    dispatch_resume(_source);
}

@end
