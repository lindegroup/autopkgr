//
//  LGPopularRepositories.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/9/14.
//
//  Copyright 2014 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGPopularRepositories.h"

@implementation LGPopularRepositories

- (id)init
{
    self = [super init];
    
    awake = NO;
    
    pkgRunner = [[LGAutoPkgRunner alloc] init];
    
    // popularRepos = [pkgRunner getLocalAutoPkgRecipeRepos];
    popularRepos = [NSArray arrayWithObjects:@"https://github.com/autopkg/recipes.git",
                                             @"https://github.com/autopkg/arubdesu-recipes.git",
                                             @"https://github.com/autopkg/dankeller-recipes.git",
                                             @"https://github.com/autopkg/derak-recipes.git",
                                             @"https://github.com/autopkg/gerardkok-recipes.git",
                                             @"https://github.com/autopkg/hansen-m-recipes.git",
                                             @"https://github.com/autopkg/hjuutilainen-recipes.git",
                                             @"https://github.com/autopkg/jaharmi-recipes.git",
                                             @"https://github.com/autopkg/jessepeterson-recipes.git",
                                             @"https://github.com/autopkg/jleggat-recipes.git",
                                             @"https://github.com/autopkg/joshua-d-miller-recipes.git",
                                             @"https://github.com/autopkg/jps3-recipes.git",
                                             @"https://github.com/autopkg/keeleysam-recipes.git",
                                             @"https://github.com/autopkg/lashomb-recipes.git",
                                             @"https://github.com/autopkg/nmcspadden-recipes.git",
                                             @"https://github.com/autopkg/rustymyers-recipes.git",
                                             @"https://github.com/autopkg/scriptingosx-recipes.git",
                                             @"https://github.com/autopkg/sheagcraig-recipes.git",
                                             @"https://github.com/autopkg/swy-recipes.git",
                                             @"https://github.com/autopkg/timsutton-recipes.git",
                                             nil];
    
    [self assembleRepos];
    
    return self;
}

- (void)reload
{
    [self assembleRepos];
}

- (void)assembleRepos
{
    activeRepos = [self getAndParseLocalAutoPkgRecipeRepos];
    
    NSMutableArray *workingPopularRepos = [NSMutableArray arrayWithArray:popularRepos];

    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"https?://(.+)" options:0 error:&error];
    
    for (NSString *repo in activeRepos) {
        NSTextCheckingResult *result = [regex firstMatchInString:repo options:0 range:NSMakeRange(0,[repo length])];
        if ([result numberOfRanges] == 2) {
            NSString *workingString = [repo substringWithRange:[result rangeAtIndex:1]];
            
            NSUInteger searchResult = [self string:workingString inArray:workingPopularRepos];
            
            if (searchResult == NSNotFound) {
                [workingPopularRepos addObject:[repo substringWithRange:[result rangeAtIndex:0]]];
            } else {
                // This line is necessary to resolve http / https conflicts
                [workingPopularRepos replaceObjectAtIndex:searchResult withObject:repo];
            }
        }
    }
    
    popularRepos = [NSArray arrayWithArray:workingPopularRepos];
    [self executeRepoSearch:nil];
}

- (NSUInteger)string:(NSString *)s inArray:(NSArray *)a
{
    NSUInteger match = NSNotFound;
    for (NSString *ws in a) {
        NSRange range = [ws rangeOfString:s];
        if (!NSEqualRanges(range, NSMakeRange(NSNotFound, 0))) {
            match = [a indexOfObject:ws];
            break;
        }
    }
    return match;
}

- (NSArray *)getAndParseLocalAutoPkgRecipeRepos // Strips out the local path of the cloned git repository and returns an array with only the URLs
{
    NSArray *repos = [pkgRunner getLocalAutoPkgRecipeRepos];
    NSMutableArray *strippedRepos = [[NSMutableArray alloc] init];
 
    NSError *error = NULL;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\((https?://.+)\\)" options:0 error:&error];
    
    for (NSString *repo in repos) {
        NSTextCheckingResult *result = [regex firstMatchInString:repo options:0 range:NSMakeRange(0,[repo length])];
        if ([result numberOfRanges] == 2) {
            [strippedRepos addObject:[repo substringWithRange:[result rangeAtIndex:1]]];
        }
    }
    
    return [NSArray arrayWithArray:strippedRepos];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [searchedRepos count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        NSString *repo = [searchedRepos objectAtIndex:row];
        
        NSError *error = NULL;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"https?://(.+)" options:0 error:&error];
        NSTextCheckingResult *result = [regex firstMatchInString:repo options:0 range:NSMakeRange(0, [repo length])];
        
        if ([result numberOfRanges] == 2) {
            if ([self string:[repo substringWithRange:[result rangeAtIndex:1]] inArray:activeRepos] == NSNotFound) {
                return @NO;
            } else {
                return @YES;
            }
        } else {
            return @NO;
        }
    } else if ([[tableColumn identifier] isEqualToString:@"repoURL"]) {
        return [searchedRepos objectAtIndex:row];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        if ([object isEqual:@YES]) {
            [pkgRunner addAutoPkgRecipeRepo:[searchedRepos objectAtIndex:row]];
        } else {
            [pkgRunner removeAutoPkgRecipeRepo:[searchedRepos objectAtIndex:row]];
        }
        activeRepos = [self getAndParseLocalAutoPkgRecipeRepos];
        [_appObject reload];
    }
}

- (void)executeRepoSearch:(id)sender
{
    if (awake == NO) {
        searchedRepos = [NSArray arrayWithArray:popularRepos];
        return;
    }

    [popularRepositoriesTableView beginUpdates];
    [popularRepositoriesTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    
    if ([[_repoSearch stringValue] isEqualToString:@""]) {
        searchedRepos = popularRepos;
    } else {
        NSMutableArray *workingSearchArray = [[NSMutableArray alloc] init];
        
        for (NSString *string in popularRepos) {
            NSRange range = [string rangeOfString:[_repoSearch stringValue] options:NSCaseInsensitiveSearch];
            if ( !NSEqualRanges(range, NSMakeRange(NSNotFound, 0))) {
                [workingSearchArray addObject:string];
            }
        }
        
        searchedRepos = [NSArray arrayWithArray:workingSearchArray];
    }
    
    [popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,searchedRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [popularRepositoriesTableView endUpdates];
}

- (void)awakeFromNib
{
    awake = YES;
    [_repoSearch setTarget:self];
    [_repoSearch setAction:@selector(executeRepoSearch:)];
}

@end
