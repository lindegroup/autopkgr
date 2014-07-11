//
//  LGPopularRepositories.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/9/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGPopularRepositories.h"

@implementation LGPopularRepositories

- (id)init
{
    self = [super init];
    
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

- (void)reload // TODO:  This doesn't seem to work and I can't figure out why.
{
    [popularRepositoriesTableView beginUpdates];
    [popularRepositoriesTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,popularRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [self assembleRepos];
    [popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,popularRepos.count)] withAnimation:NSTableViewAnimationEffectNone];
    [popularRepositoriesTableView endUpdates];
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
            
            if ([self stringInPopularRepos:workingString] == NO) {
                [workingPopularRepos addObject:[repo substringWithRange:[result rangeAtIndex:0]]];
            }
        }
    }
    
    popularRepos = [NSArray arrayWithArray:workingPopularRepos];
}

- (BOOL)stringInActiveRepos:(NSString *)s
{
    BOOL foundMatch = NO;
    for (NSString *actRepo in activeRepos) {
        if ([actRepo hasSuffix:s]) {
            foundMatch = YES;
            break;
        }
    }
    return foundMatch;
}

- (BOOL)stringInPopularRepos:(NSString *)s
{
    BOOL foundMatch = NO;
    for (NSString *popRepo in popularRepos) {
        if ([popRepo hasSuffix:s]) {
            foundMatch = YES;
            break;
        }
    }
    return foundMatch;
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
    return [popularRepos count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        NSString *repo = [popularRepos objectAtIndex:row];
        
        NSError *error = NULL;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"https?://(.+)" options:0 error:&error];
        NSTextCheckingResult *result = [regex firstMatchInString:repo options:0 range:NSMakeRange(0, [repo length])];
        
        if ([result numberOfRanges] == 2) {
            if ([self stringInActiveRepos:[repo substringWithRange:[result rangeAtIndex:1]]]) {
                return @YES;
            } else {
                return @NO;
            }
        } else {
            return @NO;
        }
    } else if ([[tableColumn identifier] isEqualToString:@"repoURL"]) {
        return [popularRepos objectAtIndex:row];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        if ([object isEqual:@YES]) {
            [pkgRunner addAutoPkgRecipeRepo:[popularRepos objectAtIndex:row]];
        } else {
            [pkgRunner removeAutoPkgRecipeRepo:[popularRepos objectAtIndex:row]];
        }
        activeRepos = [self getAndParseLocalAutoPkgRecipeRepos];
    }
}

- (void)awakeFromNib
{
    /* [popularRepositoriesTableView beginUpdates];
    [popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,popularRepos.count)] withAnimation:NSTableViewAnimationEffectFade];
    [popularRepositoriesTableView endUpdates]; */
}

@end
