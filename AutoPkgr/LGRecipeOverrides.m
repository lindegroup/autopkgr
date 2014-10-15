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

const CFStringRef kUTTypePropertyList = CFSTR("com.apple.property-list");

@implementation LGRecipeOverrides

+ (NSMenu *)contextualMenuForRecipe:(NSString *)recipe
{
    NSMenu *menu;
    NSMenuItem *item;
    NSMenuItem *item2;

    NSString *currentEditor = [[LGDefaults standardUserDefaults] objectForKey:@"RecipeEditor"];

    BOOL overrideExists = [self overrideExistsForRecipe:recipe];
    menu = [[NSMenu alloc] init];

    NSMenu *recipeEditorMenu = [[NSMenu alloc] init];
    NSMenuItem *recipeEditorMenuItem = [[NSMenuItem alloc] initWithTitle:@"Set Recipe Editor" action:nil keyEquivalent:@""];

    for (NSString *editor in [self recipeEditors]) {
        NSMenuItem *editorItem = [[NSMenuItem alloc] initWithTitle:editor action:@selector(setRecipeEditor:) keyEquivalent:@""];
        if ([editor isEqualToString:currentEditor]) {
            [editorItem setState:NSOnState];
        }
        editorItem.target = [self class];
        [recipeEditorMenu addItem:editorItem];
    }

    NSMenuItem *otherEditorItem = [[NSMenuItem alloc] initWithTitle:@"Other..." action:@selector(setRecipeEditor:) keyEquivalent:@""];
    otherEditorItem.target = [self class];

    [recipeEditorMenu addItem:otherEditorItem];

    if (overrideExists) {
        item = [[NSMenuItem alloc] initWithTitle:@"Open Recipe Override" action:@selector(openFile:) keyEquivalent:@""];

        // Reveal in finder menu item
        item2 = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(revealInFinder:) keyEquivalent:@""];
        item2.representedObject = recipe;
        item2.target = [self class];

    } else {
        item = [[NSMenuItem alloc] initWithTitle:@"Create Override" action:@selector(createOverride:) keyEquivalent:@""];
    }

    item.representedObject = recipe;
    item.target = [self class];

    if (item) {
        [menu addItem:item];
    }

    if (item2) {
        [menu addItem:item2];
    }

    [menu addItem:recipeEditorMenuItem];
    [menu setSubmenu:recipeEditorMenu forItem:recipeEditorMenuItem];
    return menu;
}

#pragma mark - Override Actions
+ (void)createOverride:(NSMenuItem *)sender
{
    NSLog(@"Creating override for %@", sender.representedObject);
    [LGAutoPkgTask makeOverride:sender.representedObject reply:^(NSError *error) {
        if (error) {
            NSLog(@"%@",error.localizedDescription);
        }
    }];
}

+ (void)deleteOverride:(NSMenuItem *)sender
{
    NSString *recipePath = [self overridePathFromRecipe:sender.representedObject];
    NSAlert *alert = [NSAlert alertWithMessageText:@"AutoPkgr is trying to remove override" defaultButton:@"Remove" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Are you sure you want to remove the %@ recipe override?  Any changes made to the file will be lost.", sender.representedObject];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [[NSFileManager defaultManager] removeItemAtPath:recipePath error:nil];
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

+ (BOOL)overrideExistsForRecipe:(NSString *)recipe
{
    NSString *recipePath = [self overridePathFromRecipe:recipe];
    return [[NSFileManager defaultManager] fileExistsAtPath:recipePath];
}

+ (NSString *)overridePathFromRecipe:(NSString *)recipe
{
    NSString *overrideDir = [[LGDefaults standardUserDefaults] autoPkgRecipeOverridesDir];
    if (!overrideDir) {
        overrideDir = [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    }

    return [[overrideDir stringByAppendingPathComponent:recipe]
        stringByAppendingPathExtension:@"recipe"];
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
    return (__bridge NSArray *)(LSCopyAllRoleHandlersForContentType(utType, kLSRolesAll));
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
