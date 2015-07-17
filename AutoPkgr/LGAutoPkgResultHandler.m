//
//  LGAutoPkgResultHandler.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/15/15.
//  Copyright 2015 Eldon Ahrold.
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

#import "LGAutoPkgResultHandler.h"
#import "LGAutoPkgTask.h"

#import "NSData+taskData.h"

@interface LGAutoPkgResultHandler ()
@property (copy, nonatomic, readonly) NSString *dataString;
@end

@implementation LGAutoPkgResultHandler {
    NSData *_data;
    LGAutoPkgVerb _verb;
}

@synthesize dataString = _dataString;

- (instancetype)initWithString:(NSString *)string verb:(LGAutoPkgVerb)verb;
{
    self = [super init];
    if (self) {
        _dataString = string;
        _verb = verb;
    }
    return self;
}

- (instancetype)initWithData:(NSData *)data verb:(LGAutoPkgVerb)verb
{
    self = [super init];
    if (self) {
        _data = data;
        _verb = verb;
    }
    return self;
}

- (NSString *)dataString
{
    if (!_dataString) {
        _dataString = [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding];
    }
    return _dataString;
}

- (id)results
{
    id _results;

    if (!_results) {
        switch (_verb) {
        case kLGAutoPkgUndefinedVerb: {
            break;
        }
        case kLGAutoPkgRun: {
            break;
        }
#pragma mark List Recipe
        case kLGAutoPkgListRecipes: {
            // Try to serialize the stdout, if that fails continue
            if ((_results = _data.taskData_serializePropertyList)) {
                return _results;
            }

            NSMutableArray *recipes = nil;
            NSArray *listResults = self.dataString.split_byLine;
            if (listResults.count) {
                recipes = [NSMutableArray arrayWithCapacity:listResults.count];
                [listResults enumerateObjectsUsingBlock:^(NSString *str, NSUInteger idx, BOOL *stop) {
                        if (str.length) {
                            NSArray *split = str.split_bySpace;
                            if (split.count) {
                                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:split.count];

                                if (split.count > 1) {
                                    [dict setObject:split[1] forKey:kLGAutoPkgRecipeIdentifierKey];
                                }

                                [dict setObject:split.firstObject forKey:kLGAutoPkgRecipeNameKey];
                                [recipes addObject:dict];
                                
                            }
                        }
                }];
            }

            _results = [recipes copy];
            break;
        }
        case kLGAutoPkgMakeOverride: {
            break;
        }
#pragma mark Search
        case kLGAutoPkgSearch: {

            __block NSMutableArray *searchResults;

            NSMutableCharacterSet *repoCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
            [repoCharacters formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];

            NSCharacterSet *skippedCharacters = [NSCharacterSet whitespaceCharacterSet];

            NSPredicate *skipLinePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'To add' \
                                                                                or SELF BEGINSWITH '----' \
                                                                                or SELF BEGINSWITH 'Name'"];

            [self.dataString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
                    if (![skipLinePredicate evaluateWithObject:line ]) {
                        NSScanner *scanner = [NSScanner scannerWithString:line];
                        [scanner setCharactersToBeSkipped:skippedCharacters];

                        NSString *recipe, *repo, *path;

                        [scanner scanCharactersFromSet:repoCharacters intoString:&recipe];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&repo];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&path];


                        if (recipe && repo && path) {
                            if (!searchResults) {
                                searchResults = [[NSMutableArray alloc] init];
                            }
                            [searchResults addObject:@{kLGAutoPkgRecipeNameKey:[recipe stringByDeletingPathExtension],
                                                       kLGAutoPkgRepoNameKey:repo,
                                                       kLGAutoPkgRecipePathKey:path,
                                                       }];
                        }
                    }
            }];

            _results = [searchResults copy];
            break;
        }
        case kLGAutoPkgInfo: {
            break;
        }
        case kLGAutoPkgRepoAdd: {
            break;
        }
        case kLGAutoPkgRepoDelete: {
            break;
        }
        case kLGAutoPkgRepoUpdate: {
            break;
        }
#pragma mark Repo List
        case kLGAutoPkgRepoList: {
            NSArray *listResults = self.dataString.split_byLine;
            __block NSMutableArray *repos = nil;

            if ([listResults.firstObject hasPrefix:@"No recipe repos"]) {
                break;
            }

            NSMutableCharacterSet *skippedCharacters = [NSMutableCharacterSet whitespaceCharacterSet];
            [skippedCharacters addCharactersInString:@"()"];

            NSMutableCharacterSet *repoCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
            [repoCharacters formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
            [repoCharacters removeCharactersInString:@"()"];

            [listResults enumerateObjectsUsingBlock:^(NSString *repo, NSUInteger idx, BOOL *stop) {
                    if (repo.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:repo];
                        [scanner setCharactersToBeSkipped:skippedCharacters];

                        NSString *repoPath, *repoUrl;

                        [scanner scanCharactersFromSet:repoCharacters intoString:&repoPath];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&repoUrl];

                        if (repoPath.length && repoUrl.length) {
                            if (repos || (repos = [[NSMutableArray alloc] init])) {
                                [repos addObject:@{kLGAutoPkgRepoURLKey : repoUrl.trimmed,
                                                   kLGAutoPkgRepoPathKey : repoPath.trimmed}];
                            }
                        }
                    }
            }];

            _results = [repos copy];
            break;
        }
        case kLGAutoPkgProcessorInfo: {
            break;
        }
#pragma mark List Processors
        case kLGAutoPkgListProcessors: {
            _results = self.dataString.split_byLine;
            break;
        }
        case kLGAutoPkgVersion: {
            break;
        }
        default: {
            break;
        }
        }
    }
    return _results;
}

@end
