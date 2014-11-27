// LGRecipeOverrides.m
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

#import "LGRecipeOverrides.h"
#import "LGDefaults.h"
#import "LGAutoPkgTask.h"

NSString *const kLGNotificationOverrideCreated = @"com.lindegroup.AutoPkgr.notification.override.created";
NSString *const kLGNotificationOverrideDeleted = @"com.lindegroup.AutoPkgr.notification.override.deleted";

const CFStringRef kUTTypePropertyList = CFSTR("com.apple.property-list");

@implementation LGRecipeOverrides

#pragma mark - Override Actions
+ (void)createOverride:(NSMenuItem *)sender
{
    NSDictionary *recipe = sender.representedObject;
    NSString *recipeName = recipe[kLGAutoPkgRecipeNameKey];
    NSString *recipeIdentifier = recipe[kLGAutoPkgRecipeIdentifierKey];

    NSLog(@"Creating override for %@", recipeName);
    [LGAutoPkgTask makeOverride:recipeIdentifier reply:^(NSString *path, NSError *error) {
        if (error) {
            NSLog(@"%@",error.localizedDescription);
            [NSApp presentError:error];
        } else {
            NSDictionary *override = [NSDictionary dictionaryWithContentsOfFile:path] ?: @{};
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationOverrideCreated
                                                                   object:nil
                                                                 userInfo:@{@"old":recipe,
                                                                            @"new":override}];
            }];
        }
    }];
}

+ (void)deleteOverride:(NSMenuItem *)sender
{
    NSDictionary *recipeToRemoveDict = sender.representedObject;
    NSString *recipeName = recipeToRemoveDict[kLGAutoPkgRecipeNameKey];
    NSString *recipeIdentifier = recipeToRemoveDict[kLGAutoPkgRecipeIdentifierKey];

    NSString *recipePath = [self overridePathFromRecipe:recipeToRemoveDict];
    
    NSDictionary *overrideDict = [NSDictionary dictionaryWithContentsOfFile:recipePath];

    // If these don't match then we're trying to remove the wrong override, abort...
    if (![recipeIdentifier isEqualToString:overrideDict[kLGAutoPkgRecipeIdentifierKey]]) {
        return;
    }

    NSAlert *alert = [NSAlert alertWithMessageText:@"AutoPkgr is trying to remove a recipe override." defaultButton:@"Remove" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Are you sure you want to remove the %@ recipe override? Any changes made to the file will be lost.", recipeName];
    NSLog(@"Displaying prompt to confirm deletion of override %@", recipeName);

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        if ([[NSFileManager defaultManager] removeItemAtPath:recipePath error:nil]) {
            NSLog(@"Override %@ deleted.", recipeName);

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationOverrideDeleted
                                                               object:nil
                                                             userInfo:recipeToRemoveDict];
            }];
        }
    }
}

+ (void)openFile:(NSMenuItem *)sender
{
    NSString *recipePath = [self overridePathFromRecipe:sender.representedObject];
    if (recipePath) {
        [[NSWorkspace sharedWorkspace] openFile:recipePath];
    } else {
        NSLog(@"There was a problem opening the Recipe override file");
    }
}

+ (void)revealInFinder:(NSMenuItem *)sender
{
    NSString *recipePath = [self overridePathFromRecipe:sender.representedObject];
    [[NSWorkspace sharedWorkspace] selectFile:recipePath inFileViewerRootedAtPath:nil];
}

+ (BOOL)overrideExistsForRecipe:(NSDictionary *)recipe
{
    NSString *recipePath = [self overridePathFromRecipe:recipe];
    return [[NSFileManager defaultManager] fileExistsAtPath:recipePath];
}

+ (NSString *)overridePathFromRecipe:(NSDictionary *)recipe
{
    NSString *overridesDir = [[LGDefaults standardUserDefaults] autoPkgRecipeOverridesDir]?:
                                        @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

    NSArray *overrides = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:overridesDir error:nil];
    
    for (NSString *item in overrides) {
        NSString *overridePath = [overridesDir stringByAppendingPathComponent:item];
        NSDictionary *override = [NSDictionary dictionaryWithContentsOfFile:overridePath];
        if (override && [override[kLGAutoPkgRecipeIdentifierKey] isEqualTo:recipe[kLGAutoPkgRecipeIdentifierKey]]) {
            return overridePath;
        }
    }
    return nil;
}

#pragma mark - Recipe Editor
+ (void)setRecipeEditor:(NSMenuItem *)item
{
    NSString *newEditor;
    if ([item.title isEqual:@"Other..."]) {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        [panel setCanChooseDirectories:NO];
        [panel setAllowedFileTypes:@[ @"app" ]];
        [panel setTitle:@"Choose an editor for AutoPkgr recipe overrides"];
        [panel.defaultButtonCell setTitle:@"Choose"];

        NSInteger button = [panel runModal];
        if (button == NSFileHandlingPanelOKButton) {
            newEditor = [[[panel.URL pathComponents] lastObject] stringByDeletingPathExtension];
        } else {
            return;
        }

    } else {
        newEditor = item.title;
    }

    [[self class] setRecipeEditorApplication:newEditor];

    for (NSMenuItem *oldItem in [[item menu] itemArray]) {
        [oldItem setState:NSOffState];
    }
    [item setState:NSOnState];
}

+ (NSArray *)recipeEditors
{
    NSMutableArray *include = [[NSMutableArray alloc] init];

    NSArray *plistEditors = [self editorForType:kUTTypePropertyList];
    if (plistEditors)
        [include addObject:plistEditors];

    NSArray *xmlEditors = [self editorForType:kUTTypeXML];
    if (xmlEditors)
        [include addObject:xmlEditors];

    NSArray *sourceCode = [self editorForType:kUTTypeSourceCode];
    if (sourceCode)
        [include addObject:sourceCode];

    NSArray *plainTextEditors = [self editorForType:kUTTypePlainText];
    if (plainTextEditors)
        [include addObject:plainTextEditors];

    NSMutableSet *editorsNames = [[NSMutableSet alloc] init];

    for (NSArray *arr in include) {
        for (NSString *editor in arr) {
            NSString *path = [[NSWorkspace sharedWorkspace]
                absolutePathForAppBundleWithIdentifier:editor];

            NSString *app = [[path lastPathComponent] stringByDeletingPathExtension];
            if (app) {
                [editorsNames addObject:app];
            }
        }
    }

    // In the event that the specified app is not registered in the LS database, we keep
    // record of it in the user preferences
    NSString *currentEditor = [[LGDefaults standardUserDefaults] objectForKey:@"RecipeEditor"];
    if (currentEditor) {
        [editorsNames addObject:currentEditor];
    }

    return [editorsNames allObjects];
}

+ (NSArray *)editorForType:(CFStringRef)utType
{
    return CFBridgingRelease(LSCopyAllRoleHandlersForContentType(utType, kLSRolesAll));
}

+ (BOOL)setRecipeEditorApplication:(NSString *)application
{
    NSString *appPath = [[NSWorkspace sharedWorkspace] fullPathForApplication:application];
    NSString *appID = [[NSBundle bundleWithPath:appPath] bundleIdentifier];
    OSStatus success = LSSetDefaultRoleHandlerForContentType(
        (__bridge CFStringRef)[self UTIforRecipeExtension], kLSRolesAll,
        (__bridge CFStringRef)appID);

    if (success == 0) {
        [[LGDefaults standardUserDefaults] setObject:application forKey:@"RecipeEditor"];
    }
    return (success = 0);
}

+ (NSString *)UTIforRecipeExtension
{
    return CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                                   CFSTR("recipe"),
                                                                   NULL));
}
@end
