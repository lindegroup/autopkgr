// LGRecipeTableView.m
// AutoPkgr
//
// Created by Eldon on 8/14/14.
//
// Copyright 2014 The Linde Group, Inc.
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

#import "LGTableView.h"
#import "LGRecipeOverrides.h"
#import "LGPopularRepositories.h"
#import "LGJSSAddon.h"

@implementation LGTableView

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger row = [self rowAtPoint:mousePoint];
    NSString *classString = NSStringFromClass([[self dataSource] class]);

    if (theEvent.type == NSLeftMouseDown || theEvent.type == NSRightMouseDown) {
        if ([classString isEqualToString:@"LGRecipes"]) {
            NSString *recipe = [self recipeFromRow:row];
            return [(LGRecipes *)[self dataSource] contextualMenuForRecipeAtRow:row];
        } else if ([classString isEqualToString:@"LGPopularRepositories"]) {
            NSString *repo = [self repoFromRow:row];
            return [LGPopularRepositories contextualMenuForRepo:repo];
        } else if ([classString isEqualToString:@"LGJSSAddon"]) {
            NSDictionary *distributionPoint;
            if (row > -1) {
                distributionPoint = [[LGDefaults standardUserDefaults] JSSRepos][row];
            } 
            return [(LGJSSAddon *)[self dataSource] contextualMenuForDistributionPoint:distributionPoint];
        }
    }
    return nil;
}

- (NSString *)recipeFromRow:(NSInteger)row
{
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"recipeName"];
    NSString *recipe = [[self dataSource] tableView:self objectValueForTableColumn:column row:row];
    return recipe;
}

- (NSString *)repoFromRow:(NSInteger)row
{
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"repoName"];
    NSString *repo = [[self dataSource] tableView:self objectValueForTableColumn:column row:row];
    return repo;
}

@end
