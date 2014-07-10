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
    
    popularRepos = [pkgRunner getLocalAutoPkgRecipeRepos];
    
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [popularRepos count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSLog(@"HIT IT!!!!!");
    NSLog(@"Identifier: %@", [tableColumn identifier]);
    if ([[tableColumn identifier] isEqualToString:@"repoCheckbox"]) {
        return NO;
    } else if ([[tableColumn identifier] isEqualToString:@"repoURL"]) {
        NSLog(@"Returned URL: %@", [popularRepos objectAtIndex:row]);
        return [popularRepos objectAtIndex:row];
    }
    
    return nil;
}

- (void)awakeFromNib
{
    [popularRepositoriesTableView beginUpdates];
    [popularRepositoriesTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,popularRepos.count)] withAnimation:NSTableViewAnimationEffectFade];
    [popularRepositoriesTableView endUpdates];
}

@end
