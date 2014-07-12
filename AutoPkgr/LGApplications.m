//
//  LGApplications.m
//  AutoPkgr
//
//  Created by Josh Senick on 7/10/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGApplications.h"

@implementation LGApplications

- (id) init
{
    self = [super init];
    
    pkgRunner = [[LGAutoPkgRunner alloc] init];
    
    apps = [pkgRunner getLocalAutoPkgRecipes];
    activeApps = [self getActiveApps];
    
    return self;
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
    return [apps count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if ([[tableColumn identifier] isEqualToString:@"appCheckbox"]) {
        return @([activeApps containsObject:[apps objectAtIndex:row]]);
    } else if ([[tableColumn identifier] isEqualToString:@"appName"]) {
        return [apps objectAtIndex:row];
    }
    
    return nil;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if([[tableColumn identifier] isEqualToString:@"appCheckbox"]) {
        NSMutableArray *workingArray = [NSMutableArray arrayWithArray:activeApps];
        if ([object isEqual:@YES]) {
            [workingArray addObject:[apps objectAtIndex:row]];
        } else {
            NSUInteger index = [workingArray indexOfObject:[apps objectAtIndex:row]];
            if (index != NSNotFound) {
                [workingArray removeObjectAtIndex:index];
            } else {
                NSLog(@"Cannot find item %@ in workingArray", [apps objectAtIndex:row]);
            }
        }
        activeApps = [NSArray arrayWithArray:workingArray];
    }
    
    return;
}

- (void)writeRecipeList
{
    NSError *error;
    
    NSString *autoPkgrSupportDirectory = [self getAppSupportDirectory];
    if ([autoPkgrSupportDirectory isEqual:@""]) {
        NSLog(@"Could not write recipe_list.txt");
        return;
    }
    
    NSString *recipeListFile = [autoPkgrSupportDirectory stringByAppendingString:@"/recipe_list.txt"];
    
    NSString *recipe_list = [activeApps componentsJoinedByString:@"\n"];
    [recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
    if (error) {
        NSLog(@"Error while writing %@", recipeListFile);
    }
}


@end
