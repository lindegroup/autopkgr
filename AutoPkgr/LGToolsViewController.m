//
//  LGToolsViewController.m
//  AutoPkgr
//
//  Created by Eldon on 5/20/15.
//  Copyright 2015 Eldon Ahrold.
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
//  limitations under the License.//

#import "LGToolsViewController.h"
#import "LGToolManager.h"

@implementation LGToolsViewController {
    LGDefaults *_defaults;
}
@synthesize modalWindow = _modalWindow;

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do view setup here.
}

- (void)awakeFromNib
{
    if (!self.awake) {
        self.awake = YES;
        _defaults = [LGDefaults standardUserDefaults];
        // AutoPkg settings

        _localMunkiRepo.safeStringValue = _defaults.munkiRepo;
        _autoPkgCacheDir.safeStringValue = _defaults.autoPkgCacheDir;
        _autoPkgRecipeRepoDir.safeStringValue = _defaults.autoPkgRecipeRepoDir;
        _autoPkgRecipeOverridesDir.safeStringValue = _defaults.autoPkgRecipeOverridesDir;

        _jssImporter.jssImporterTool = [_toolManager toolOfClass:[LGJSSImporterTool class]];

        [_jssImporter connectToTool];
    }
}

- (void)setModalWindow:(NSWindow *)modalWindow
{
    _modalWindow = modalWindow;
    _jssImporter.modalWindow = modalWindow;
}

- (NSString *)tabLabel
{
    return @"Folders & Integration";
}

#pragma mark - Open Folder Actions
- (IBAction)openLocalMunkiRepoFolder:(id)sender
{
    DLog(@"Opening Munki repo folder...");

    NSString *munkiRepoFolder = _defaults.munkiRepo;
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:munkiRepoFolder isDirectory:&isDir] && isDir) {
        NSURL *localMunkiRepoFolderURL = [NSURL fileURLWithPath:munkiRepoFolder];
        [[NSWorkspace sharedWorkspace] openURL:localMunkiRepoFolderURL];
    } else {
        NSLog(@"%@ does not exist.", munkiRepoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the Munki repository."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the Munki repository located in %@. Please verify that this folder exists.", kLGApplicationName, munkiRepoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.modalWindow
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeRepos folder...");

    NSString *repoFolder = [_defaults autoPkgRecipeRepoDir];
    BOOL isDir;

    repoFolder = repoFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:repoFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeReposFolderURL = [NSURL fileURLWithPath:repoFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeReposFolderURL];
    } else {
        NSLog(@"%@ does not exist.", repoFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeRepos folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeRepos folder located in %@. Please verify that this folder exists.", kLGApplicationName, repoFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];

        [alert beginSheetModalForWindow:self.modalWindow
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgCacheFolder:(id)sender
{
    DLog(@"Opening AutoPkg Cache folder...");

    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    BOOL isDir;

    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgCacheFolderURL = [NSURL fileURLWithPath:cacheFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgCacheFolderURL];
    } else {
        NSLog(@"%@ does not exist.", cacheFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg Cache folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg Cache folder located in %@. Please verify that this folder exists.", kLGApplicationName, cacheFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.modalWindow
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender
{
    DLog(@"Opening AutoPkg RecipeOverrides folder...");

    NSString *overridesFolder = _defaults.autoPkgRecipeOverridesDir;
    BOOL isDir;

    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];

    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        NSURL *autoPkgRecipeOverridesFolderURL = [NSURL fileURLWithPath:overridesFolder];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgRecipeOverridesFolderURL];
    } else {
        NSLog(@"%@ does not exist.", overridesFolder);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Cannot find the AutoPkg RecipeOverrides folder."];
        [alert setInformativeText:[NSString stringWithFormat:@"%@ could not find the AutoPkg RecipeOverrides folder located in %@. Please verify that this folder exists.", kLGApplicationName, overridesFolder]];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
    }
}

#pragma mark - Choose AutoPkg Folder Actions
- (IBAction)chooseLocalMunkiRepo:(id)sender
{
    DLog(@"Showing dialog for selecting Munki repo location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for munkiRepo, else /Users/Shared
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.munkiRepo ?: @"/Users/Shared"]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.modalWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"Munki repo location selected.");
                    NSString *urlPath = [url path];
                    [_localMunkiRepo setStringValue:urlPath];
                    [_openLocalMunkiRepoFolderButton setEnabled:YES];
                    _defaults.munkiRepo = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeRepos location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeRepoDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.modalWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeRepos location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeRepoDir setStringValue:urlPath];
                    [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeRepoDir = urlPath;

                    // Since we changed the repo directory reload the table accordingly
                }
            }
        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg Cache location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgCacheDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.modalWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg Cache location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgCacheDir setStringValue:urlPath];
                    [_openAutoPkgCacheFolderButton setEnabled:YES];
                    _defaults.autoPkgCacheDir = urlPath;
                }
            }

        }
    }];
}

- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeOverrides location.");
    NSOpenPanel *chooseDialog = [self setupChoosePanel];

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    [chooseDialog setDirectoryURL:[NSURL URLWithString:_defaults.autoPkgRecipeOverridesDir ?: [@"~/Library/AutoPkg" stringByExpandingTildeInPath]]];

    // Display the dialog. If the "Choose" button was
    // pressed, process the directory path.
    [chooseDialog beginSheetModalForWindow:self.modalWindow completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *url = [chooseDialog URL];
            if ([url isFileURL]) {
                BOOL isDir = NO;
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    DLog(@"AutoPkg RecipeOverrides location selected.");
                    NSString *urlPath = [url path];
                    [_autoPkgRecipeOverridesDir setStringValue:urlPath];
                    [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
                    _defaults.autoPkgRecipeOverridesDir = urlPath;
                }
            }
            
        }
    }];
}

- (void)enableFolders
{
    // Enable "Open in Finder" buttons if directories exist
    BOOL isDir;

    // AutoPkg Recipe Repos
    NSString *recipeReposFolder = [_defaults autoPkgRecipeRepoDir];
    recipeReposFolder = recipeReposFolder ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:recipeReposFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeReposFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeReposFolderButton setEnabled:NO];
    }

    // AutoPkg Cache
    NSString *cacheFolder = [_defaults autoPkgCacheDir];
    cacheFolder = cacheFolder ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgCacheFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgCacheFolderButton setEnabled:NO];
    }

    // AutoPkg Overrides
    NSString *overridesFolder = [_defaults autoPkgRecipeOverridesDir];
    overridesFolder = overridesFolder ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:YES];
    } else {
        [_openAutoPkgRecipeOverridesFolderButton setEnabled:NO];
    }

    // Munki Repo
    if ([[NSFileManager defaultManager] fileExistsAtPath:_defaults.munkiRepo isDirectory:&isDir] && isDir) {
        [_openLocalMunkiRepoFolderButton setEnabled:YES];
    } else {
        [_openLocalMunkiRepoFolderButton setEnabled:NO];
    }
}

#pragma mark - Utility
- (NSOpenPanel *)setupChoosePanel
{
    NSOpenPanel *choosePanel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    [choosePanel setCanChooseFiles:NO];

    // Enable the selection of directories in the dialog
    [choosePanel setCanChooseDirectories:YES];

    // Enable the creation of directories in the dialog
    [choosePanel setCanCreateDirectories:YES];

    // Set the prompt to "Choose" instead of "Open"
    [choosePanel setPrompt:@"Choose"];

    // Disable multiple selection
    [choosePanel setAllowsMultipleSelection:NO];

    return choosePanel;
}

@end
