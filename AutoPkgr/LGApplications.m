//
//  LGApplications.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/10/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGApplications.h"

@implementation LGApplications

- (id)init
{
    self = [super init];
    
    pkgRunner = [[LGAutoPkgRunner alloc] init];
    
    apps = [pkgRunner getLocalAutoPkgRecipes];
    activeApps = [self getActiveApps];
    searchedApps = apps;
    
    return self;
}

- (void)reload
{
    apps = [pkgRunner getLocalAutoPkgRecipes];
    
    [self executeAppSearch:self];
}

- (NSString *)getAppSupportDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    NSString *autoPkgrSupportDirectory = [applicationSupportDirectory stringByAppendingString:@"/AutoPkgr"];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    NSError *error;
    
    if ([fm fileExistsAtPath:autoPkgrSupportDirectory isDirectory:&isDir]) {
        if (!isDir) {
            [fm removeItemAtPath:autoPkgrSupportDirectory error:&error];
            if (error) {
                NSLog(@"%@ is a file, and it cannot be deleted.", autoPkgrSupportDirectory);
                return @"";
            }
            [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
            if (error) {
                NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
                return @"";
            }
        }
    } else {
        [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
        if (error) {
            NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
            return @"";
        }
    }
    
    return autoPkgrSupportDirectory;

}

- (NSArray *)getActiveApps
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSString *autoPkgrSupportDirectory = [self getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        return [[NSArray alloc] init];
    }
    
    NSString *autoPkgrRecipeListPath = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    if ([fm fileExistsAtPath:autoPkgrRecipeListPath]) {
        NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:autoPkgrRecipeListPath encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading %@.", autoPkgrRecipeList);
            return [[NSArray alloc] init];
        }
        
        return [autoPkgrRecipeList componentsSeparatedByString:@"\n"];
        
    } else {
        return [[NSArray alloc] init];
    }
    
    return [[NSArray alloc] init];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [searchedApps count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"appCheckbox"]) {
        return @([activeApps containsObject:[searchedApps objectAtIndex:row]]);
    } else if ([[tableColumn identifier] isEqualToString:@"appName"]) {
        return [searchedApps objectAtIndex:row];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if([[tableColumn identifier] isEqualToString:@"appCheckbox"]) {
        NSMutableArray *workingArray = [NSMutableArray arrayWithArray:activeApps];
        if ([object isEqual:@YES]) {
            [workingArray addObject:[searchedApps objectAtIndex:row]];
        } else {
            NSUInteger index = [workingArray indexOfObject:[searchedApps objectAtIndex:row]];
            if (index != NSNotFound) {
                [workingArray removeObjectAtIndex:index];
            } else {
                NSLog(@"Cannot find item %@ in workingArray", [searchedApps objectAtIndex:row]);
            }
        }
        activeApps = [NSArray arrayWithArray:workingArray];
        [self writeRecipeList];
    }
    
    return;
}

- (void)cleanActiveApps
{
    // This runs through the updated recipes and removes any recipes from the
    // activeApps array that cannot be found in the new apps array.
    
    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:activeApps];

    for (NSString *string in activeApps) {
        if (![apps containsObject:string]) {
            [workingArray removeObject:string];
        }
    }
    
    activeApps = [NSArray arrayWithArray:workingArray];
}

- (void)writeRecipeList
{
    [self cleanActiveApps];
    
    NSError *error;
    
    NSString *autoPkgrSupportDirectory = [self getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        NSLog(@"Could not write recipe_list.txt");
        return;
    }
    
    NSString *recipeListFile = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    
    NSPredicate *makeCatalogPredicate = [NSPredicate predicateWithFormat:@"not SELF contains[cd] %@",@"MakeCatalogs.munki"];
    NSPredicate *munkiPredicate = [NSPredicate predicateWithFormat:@"SELF contains[cd] %@",@"munki"];
    
    // Make a working array filtering out any instances of MakeCatalogs.munki, so there will only be one occurence
    NSMutableArray * workingArray = [NSMutableArray arrayWithArray:[activeApps filteredArrayUsingPredicate:makeCatalogPredicate]];

    // Check if any of the apps is a .munki run
    if ([workingArray filteredArrayUsingPredicate:munkiPredicate].count) {
        // If so add MakeCatalogs.munki to the end of the list (so it runs last)
        [workingArray addObject:@"MakeCatalogs.munki"];
    }
    
    NSString *recipe_list = [workingArray componentsJoinedByString:@"\n"];
    
    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"Error while writing %@", recipeListFile);
    }
}

- (void)executeAppSearch:(id)sender
{
    [applicationTableView beginUpdates];
    [applicationTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,searchedApps.count)] withAnimation:NSTableViewAnimationEffectNone];
    
    if ([[_appSearch stringValue] isEqualToString:@""]) {
        searchedApps = apps;
    } else {
        NSMutableArray *workingSearchArray = [[NSMutableArray alloc] init];
        
        for (NSString *string in apps) {
            NSRange range = [string rangeOfString:[_appSearch stringValue] options:NSCaseInsensitiveSearch];
            
            if (!NSEqualRanges(range, NSMakeRange(NSNotFound, 0))) {
                [workingSearchArray addObject:string];
            }
        }
        
        searchedApps = [NSArray arrayWithArray:workingSearchArray];
    }
    
    [applicationTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,searchedApps.count)] withAnimation:NSTableViewAnimationEffectNone];

    [applicationTableView endUpdates];
}

- (void)awakeFromNib
{
    [_appSearch setTarget:self];
    [_appSearch setAction:@selector(executeAppSearch:)];
}

@end
