
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

#import "LGJSSImporterIntegrationView.h"
#import "LGMunkiIntegrationView.h"
#import "LGAbsoluteManageIntegrationView.h"

#import "LGIntegrationWindowController.h"
#import "LGTableCellViews.h"

#import "NSOpenPanel+folderChooser.h"

@interface LGToolsViewController ()<NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation LGToolsViewController {
    LGDefaults *_defaults;
    LGIntegrationWindowController *integrationWindowController;
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
        _autoPkgCacheDir.safeStringValue = _defaults.autoPkgCacheDir;
        _autoPkgRecipeRepoDir.safeStringValue = _defaults.autoPkgRecipeRepoDir;
        _autoPkgRecipeOverridesDir.safeStringValue = _defaults.autoPkgRecipeOverridesDir;
    }
}

- (void)setModalWindow:(NSWindow *)modalWindow
{
    _modalWindow = modalWindow;
}

- (NSString *)tabLabel
{
    return @"Folders & Integration";
}

- (NSArray *)tableViewIntegrations
{
    return _toolManager.optionalTools;
}

#pragma mark - Integration config

- (Class)viewControllerClassForIntegration:(LGTool *)integration {
    Class viewClass = NULL;
    if ([integration isMemberOfClass:[LGJSSImporterTool class]]) {
        viewClass = [LGJSSImporterIntegrationView class];
    } else if ([integration isMemberOfClass:[LGMunkiTool class]]) {
        viewClass = [LGMunkiIntegrationView class];
    } else if ([integration isMemberOfClass:[LGAbsoluteManageIntegration class]]){
        viewClass = [LGAbsoluteManageIntegrationView class];
    }
    
    return viewClass;
}

- (void)configure:(NSButton *)sender
{
    LGTool *integration = [[self tableViewIntegrations] objectAtIndex:sender.tag];
    Class viewClass = [self viewControllerClassForIntegration:integration];

    if (viewClass) {
        LGBaseIntegrationViewController *integrationView = [[viewClass alloc] initWithIntegration:integration];

        integrationWindowController = [[LGIntegrationWindowController alloc] initWithViewController:integrationView];

        [NSApp beginSheet:integrationWindowController.window
           modalForWindow:self.modalWindow
            modalDelegate:self
           didEndSelector:@selector(didEndIntegrationConfigurePanel:)
              contextInfo:NULL];
    }
}

- (void)didEndIntegrationConfigurePanel:(id)sender
{
    integrationWindowController = nil;
}

#pragma mark - Table View
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self tableViewIntegrations].count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{
    __block LGToolStatusTableCellView *statusCell = nil;
    if ([tableColumn.identifier isEqualToString:@"statusCell"]) {

        LGTool *tool = [self tableViewIntegrations][row];
        tool.progressDelegate = self.progressDelegate;

        statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

        statusCell.configureButton.target = tool;
        statusCell.configureButton.tag = row;

        statusCell.configureButton.enabled = YES;
        statusCell.configureButton.title = [@"Install " stringByAppendingString:[[tool class] name]];

        statusCell.textField.stringValue = [[[tool class] name] stringByAppendingString:@": checking status"];

        statusCell.imageView.hidden = YES;
        [statusCell.progressIndicator startAnimation:nil];

        __weak typeof(tool) __weak_tool = tool;
        tool.infoUpdateHandler = ^(LGToolInfo *info){
            [statusCell.progressIndicator stopAnimation:nil];
            statusCell.imageView.hidden = NO;
            statusCell.imageView.image = info.statusImage;
            statusCell.textField.stringValue = info.statusString;

            statusCell.configureButton.title = info.configureButtonTitle;
            statusCell.configureButton.action = info.configureButtonTargetAction;
            if (info.status != kLGToolNotInstalled) {
                statusCell.configureButton.target = self;
            } else {
                statusCell.configureButton.target = __weak_tool;
            }
        };
        
        if (tool.isRefreshing == NO) {
            [tool refresh];
        }
    }
    return statusCell;
}


#pragma mark - Open Folder Actions
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


- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeRepos location.");

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgRecipeRepoDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;

    [NSOpenPanel folderChooserWithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if(selectedFolder){
            DLog(@"AutoPkg RecipeRepos location selected.");
            _autoPkgRecipeRepoDir.stringValue = selectedFolder;
            _defaults.autoPkgRecipeRepoDir = selectedFolder;
            _openAutoPkgRecipeReposFolderButton.enabled = YES;
        }
    }];
}

- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DevLog(@"Showing dialog for selecting AutoPkg Cache location.");

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgCacheDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;
    [NSOpenPanel folderChooserWithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if (selectedFolder) {
            DevLog(@"AutoPkg Cache location selected.");
            _openAutoPkgCacheFolderButton.enabled = YES;
            _autoPkgCacheDir.stringValue = selectedFolder;
            _defaults.autoPkgCacheDir = selectedFolder;
        }
    }];
}

- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    DevLog(@"Showing dialog for selecting AutoPkg RecipeOverrides location.");

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;

    [NSOpenPanel folderChooserWithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if (selectedFolder) {
            DevLog(@"AutoPkg RecipeOverrides location selected.");
            _autoPkgRecipeOverridesDir.stringValue = selectedFolder;
            _openAutoPkgRecipeOverridesFolderButton.enabled = YES;
            _defaults.autoPkgRecipeOverridesDir = selectedFolder;
        }
    }];
}

- (void)enableFolders
{
    NSFileManager *fm = [NSFileManager defaultManager];

    // Enable "Open in Finder" buttons if directories exist
    BOOL isDir;

    // AutoPkg Recipe Repos
    NSString *recipeReposFolder = _defaults.autoPkgRecipeRepoDir ?: @"~/Library/AutoPkg/RecipeRepos".stringByExpandingTildeInPath;

    if ([fm fileExistsAtPath:recipeReposFolder isDirectory:&isDir] && isDir) {
        _openAutoPkgRecipeReposFolderButton.enabled = YES;
    } else {
        _openAutoPkgRecipeReposFolderButton.enabled = NO;
    }

    // AutoPkg Cache
    NSString *cacheFolder = _defaults.autoPkgCacheDir ?: @"~/Library/AutoPkg/Cache".stringByExpandingTildeInPath;
    if ([fm fileExistsAtPath:cacheFolder isDirectory:&isDir] && isDir) {
        _openAutoPkgCacheFolderButton.enabled = YES;
    } else {
        _openAutoPkgCacheFolderButton.enabled = NO;
    }

    // AutoPkg Overrides
    NSString *overridesFolder = _defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath;

    if ([fm fileExistsAtPath:overridesFolder isDirectory:&isDir] && isDir) {
        _openAutoPkgRecipeOverridesFolderButton.enabled = YES;
    } else {
        _openAutoPkgRecipeOverridesFolderButton.enabled = NO;
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
