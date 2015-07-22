//
//  LGRecipeOverrides.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/14/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGRecipeOverrides.h"
#import "LGAutoPkgRecipe.h"
#import "LGDefaults.h"
#import "LGAutoPkgTask.h"

NSString *const kLGNotificationOverrideCreated = @"com.lindegroup.AutoPkgr.notification.override.created";
NSString *const kLGNotificationOverrideDeleted = @"com.lindegroup.AutoPkgr.notification.override.deleted";

const CFStringRef kUTTypePropertyList = CFSTR("com.apple.property-list");

@implementation LGRecipeOverrides

#pragma mark - Override Actions
+ (void)createOverride:(NSMenuItem *)sender
{
    LGAutoPkgRecipe *recipe = sender.representedObject;

    NSString *recipeName = recipe.Name;
    NSString *recipeIdentifier = recipe.Identifier;
    NSString *overrideName = [self promptForOverrideName:recipeName];

    if (overrideName && recipeIdentifier) {
        DevLog(@"Creating override for %@", recipeName);
        [LGAutoPkgTask makeOverride:recipeIdentifier name:overrideName reply:^(NSString *path, NSError *error) {
            if (error) {
                DLog(@"%@",error.localizedDescription);
                [NSApp presentError:error];
            } else {
                 LGAutoPkgRecipe *override = [[LGAutoPkgRecipe alloc] initWithRecipeFile:[NSURL fileURLWithPath:path] isOverride:YES];
                assert([[NSFileManager defaultManager] fileExistsAtPath:path]);

                // if they have the same Name mark the override as enabled,
                // and the old recipe as disabled.
                if (recipe.enabled && [recipe.Name isEqualToString:override.Name]) {
                    recipe.enabled = NO;
                    override.enabled = YES;
                }

                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [[NSNotificationCenter defaultCenter]postNotificationName:kLGNotificationOverrideCreated
                                                                       object:nil
                                                                     userInfo:@{@"new": override,
                                                                                @"old": recipe}];
                }];
            }
        }];
    }
}

+ (void)deleteOverride:(NSMenuItem *)sender
{
    LGAutoPkgRecipe *overrideToRemove = sender.representedObject;
    NSString *recipeName = overrideToRemove.Name;
    NSString *recipePath = overrideToRemove.FilePath;

    NSString *message = NSLocalizedString(@"AutoPkgr is trying to remove a recipe override.", nil);
    NSString *infoText = NSLocalizedString(@"Are you sure you want to remove the %@ recipe override? Any changes made to the file will be lost.", nil);

    NSAlert *alert = [NSAlert alertWithMessageText:message defaultButton:@"Remove" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:infoText, recipeName];

    DevLog(@"Displaying prompt to confirm deletion of override %@", recipeName);

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        if ([[NSFileManager defaultManager] removeItemAtPath:recipePath error:nil]) {
            DLog(@"Override %@ deleted.", recipeName);
            overrideToRemove.enabled = NO;

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationOverrideDeleted
                                                                object:nil
                                                              userInfo:@{@"removed" : overrideToRemove}];
            }];
        }
    }
}

+ (NSString *)promptForOverrideName:(NSString *)parentName
{
    NSString *password;
    NSString *promptString = NSLocalizedString(@"Would you like to give the override a unique name?", nil);

    NSAlert *alert = [NSAlert alertWithMessageText:promptString
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];

    NSTextField *input = [[NSTextField alloc] init];
    [input setFrame:NSMakeRect(0, 0, 300, 24)];
    [input setStringValue:parentName];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        password = [input stringValue];
        if (!password || [password isEqualToString:@""]) {
            return [self promptForOverrideName:parentName];
        }
    }

    return password;
}

+ (void)openFile:(NSMenuItem *)sender
{
    NSString *recipePath = [(LGAutoPkgRecipe *)sender.representedObject FilePath];
    if (recipePath) {
        [[NSWorkspace sharedWorkspace] openFile:recipePath];
    } else {
        NSLog(@"There was a problem opening the Recipe override file");
    }
}

+ (void)revealInFinder:(NSMenuItem *)sender
{
    NSString *recipePath = [(LGAutoPkgRecipe *)sender.representedObject FilePath];
    [[NSWorkspace sharedWorkspace] selectFile:recipePath inFileViewerRootedAtPath:nil];
}

+ (BOOL)overrideExistsForRecipe:(LGAutoPkgRecipe *)recipe
{
    return (recipe.isOverride && [[NSFileManager defaultManager] fileExistsAtPath:recipe.FilePath]);
}

#pragma mark - Recipe Editor
+ (void)setRecipeEditor:(NSMenuItem *)item
{
    NSString *newEditor;
    if ([item.title isEqual:@"Other..."]) {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseDirectories = NO;
        panel.allowedFileTypes =  @[ @"app" ];
        panel.title =  NSLocalizedString(@"Choose an editor for AutoPkgr recipe overrides", nil);
        panel.defaultButtonCell.title = @"Choose";

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
