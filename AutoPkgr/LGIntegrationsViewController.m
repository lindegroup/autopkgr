
//
//  LGIntegrationsViewController.m
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

#import "LGIntegrationsViewController.h"
#import "LGIntegrationManager.h"
#import "LGAutoPkgIntegrationView.h"
#import "LGGitIntegrationView.h"
#import "LGJSSImporterIntegrationView.h"
#import "LGMunkiIntegrationView.h"
#import "LGAbsoluteManageIntegrationView.h"
#import "LGMacPatchIntegrationView.h"
#import "LGIntegrationWindowController.h"
#import "LGTableCellViews.h"

#import "NSOpenPanel+typeChooser.h"

@interface LGIntegrationsViewController () <NSTableViewDataSource, NSTableViewDelegate>
@end

@implementation LGIntegrationsViewController {
    LGDefaults *_defaults;
    LGIntegrationWindowController *_integrationWindowController;
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
        _autoPkgCacheDir.safe_stringValue = _defaults.autoPkgCacheDir.stringByAbbreviatingWithTildeInPath;
        _autoPkgRecipeRepoDir.safe_stringValue = _defaults.autoPkgRecipeRepoDir.stringByAbbreviatingWithTildeInPath;
        _autoPkgRecipeOverridesDir.safe_stringValue = _defaults.autoPkgRecipeOverridesDir.stringByAbbreviatingWithTildeInPath;
    }
}

- (void)setModalWindow:(NSWindow *)modalWindow
{
    _modalWindow = modalWindow;
}

- (NSString *)tabLabel
{
    return NSLocalizedString(@"Folders & Integration", @"Tab label");
}

#pragma mark - Integration config

- (Class)viewControllerClassForIntegration:(LGIntegration *)integration
{
    Class viewClass = NULL;
    if ([integration isMemberOfClass:[LGAutoPkgIntegration class]]) {
        viewClass = [LGAutoPkgIntegrationView class];
    } else if ([integration isMemberOfClass:[LGGitIntegration class]]) {
        viewClass = [LGGitIntegrationView class];
    } else if ([integration isMemberOfClass:[LGJSSImporterIntegration class]]) {
        viewClass = [LGJSSImporterIntegrationView class];
    } else if ([integration isMemberOfClass:[LGMunkiIntegration class]]) {
        viewClass = [LGMunkiIntegrationView class];
    } else if ([integration isMemberOfClass:[LGAbsoluteManageIntegration class]]) {
        viewClass = [LGAbsoluteManageIntegrationView class];
    }  else if ([integration isMemberOfClass:[LGMacPatchIntegration class]]) {
        viewClass = [LGMacPatchIntegrationView class];
    }

    return viewClass;
}

- (void)configure:(NSButton *)sender
{
    LGIntegration *integration = [[self tableViewIntegrations] objectAtIndex:sender.tag];
    Class viewClass = [self viewControllerClassForIntegration:integration];

    if (viewClass) {
        LGBaseIntegrationViewController *integrationView = [[viewClass alloc] initWithIntegration:integration];

        _integrationWindowController = [[LGIntegrationWindowController alloc] initWithViewController:integrationView];

        [NSApp beginSheet:_integrationWindowController.window
            modalForWindow:self.modalWindow
             modalDelegate:self
            didEndSelector:@selector(didEndIntegrationConfigurePanel:)
               contextInfo:NULL];
    }
}

- (void)didEndIntegrationConfigurePanel:(id)sender
{
    _integrationWindowController = nil;
}

#pragma mark - Table View
- (NSArray *)tableViewIntegrations
{
    return _integrationManager.allIntegrations;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self tableViewIntegrations].count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    __block LGIntegrationStatusTableCellView *statusCell = nil;
    if ([tableColumn.identifier isEqualToString:@"statusCell"]) {

        LGIntegration *integration = [self tableViewIntegrations][row];
        integration.progressDelegate = self.progressDelegate;

        statusCell = [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

        statusCell.configureButton.target = integration;
        statusCell.configureButton.tag = row;

        statusCell.configureButton.enabled = ([self viewControllerClassForIntegration:integration] != nil);

        statusCell.configureButton.title = quick_formatString(@"%@ %@",
                                                              NSLocalizedString(@"Install", nil),
                                                              integration.name);

        statusCell.textField.stringValue = quick_formatString(@"%@: %@",
                                                              integration.name,
                                                              NSLocalizedString(@"checking status", nil));

        statusCell.imageView.hidden = YES;
        [statusCell.progressIndicator startAnimation:nil];

        __weak typeof(integration) weakIntegration = integration;
        integration.infoUpdateHandler = ^(LGIntegrationInfo *info) {
            [statusCell.progressIndicator stopAnimation:nil];
            statusCell.imageView.hidden = NO;
            statusCell.imageView.image = info.statusImage;
            statusCell.textField.stringValue = info.statusString;

            statusCell.configureButton.title = info.configureButtonTitle;
            statusCell.configureButton.action = info.configureButtonTargetAction;
            if (info.status != kLGIntegrationNotInstalled) {
                statusCell.configureButton.target = self;
            } else {
                statusCell.configureButton.target = weakIntegration;
            }
        };

        if (integration.isRefreshing == NO) {
            [integration refresh];
        }
    }
    return statusCell;
}

#pragma mark - AutoPkg Cache Actions
- (IBAction)chooseAutoPkgCacheDir:(id)sender
{
    DevLog(@"Showing dialog for selecting AutoPkg Cache location.");

    // Set the default directory to the current setting for autoPkgCacheDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgCacheDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;

    [NSOpenPanel folderChooser_WithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if (selectedFolder) {
            DevLog(@"AutoPkg Cache location selected.");
            _openAutoPkgCacheFolderButton.enabled = YES;
            _autoPkgCacheDir.stringValue = selectedFolder.stringByAbbreviatingWithTildeInPath;
            _defaults.autoPkgCacheDir = selectedFolder;
        }
    }];
}

- (IBAction)openAutoPkgCacheFolder:(id)sender
{
    NSString *path = _defaults.autoPkgCacheDir ?: [@"~/Library/AutoPkg/Cache" stringByExpandingTildeInPath];
    [self openFolderAtPath:path withDescription:@"AutoPkg Cache"];
}

#pragma mark - AutoPkg Repo Actions
- (IBAction)chooseAutoPkgReciepRepoDir:(id)sender
{
    DLog(@"Showing dialog for selecting AutoPkg RecipeRepos location.");

    // Set the default directory to the current setting for autoPkgRecipeRepoDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgRecipeRepoDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;

    [NSOpenPanel folderChooser_WithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if(selectedFolder){
            DLog(@"AutoPkg RecipeRepos location selected.");
            _openAutoPkgRecipeReposFolderButton.enabled = YES;
            _autoPkgRecipeRepoDir.stringValue = selectedFolder.stringByAbbreviatingWithTildeInPath;
            _defaults.autoPkgRecipeRepoDir = selectedFolder;

        }
    }];
}

- (IBAction)openAutoPkgRecipeReposFolder:(id)sender
{
    NSString *path = [_defaults autoPkgRecipeRepoDir] ?: [@"~/Library/AutoPkg/RecipeRepos" stringByExpandingTildeInPath];
    [self openFolderAtPath:path withDescription:@"Recipe Repos"];
}


#pragma mark - AutoPkg Overrides Actions
- (IBAction)chooseAutoPkgRecipeOverridesDir:(id)sender
{
    DevLog(@"Showing dialog for selecting AutoPkg RecipeOverrides location.");

    // Set the default directory to the current setting for autoPkgRecipeOverridesDir, else ~/Library/AutoPkg
    NSString *path = _defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg".stringByExpandingTildeInPath;

    [NSOpenPanel folderChooser_WithStartingPath:path modalWindow:self.modalWindow reply:^(NSString *selectedFolder) {
        if (selectedFolder) {
            DevLog(@"AutoPkg RecipeOverrides location selected.");
            _openAutoPkgRecipeOverridesFolderButton.enabled = YES;
            _autoPkgRecipeOverridesDir.stringValue = selectedFolder.stringByAbbreviatingWithTildeInPath;
            _defaults.autoPkgRecipeOverridesDir = selectedFolder;
        }
    }];
}

- (IBAction)openAutoPkgRecipeOverridesFolder:(id)sender
{
    NSString *overridesFolder = _defaults.autoPkgRecipeOverridesDir ?: [@"~/Library/AutoPkg/RecipeOverrides" stringByExpandingTildeInPath];
    [self openFolderAtPath:overridesFolder withDescription:@"Recipe Overrides"];
}


#pragma mark - Shared
- (IBAction)saveAutoPkgFolderPath:(NSTextField *)sender {

    NSString *path = sender.stringValue.stringByExpandingTildeInPath;

    BOOL (^validFolder)(NSTextField *) = ^BOOL (NSTextField *textField) {
        BOOL isDir;
        BOOL success = NO;
        if (path.length && ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir)) {
            [sender setTextColor:[NSColor blackColor]];
            sender.stringValue = path.stringByAbbreviatingWithTildeInPath;
            success =  YES;
        } else {
            // possibly present error.
            [sender setTextColor:[NSColor redColor]];
        }
        return success;
    };

    if ([sender isEqualTo:_autoPkgCacheDir] && validFolder(sender)) {
        _defaults.autoPkgCacheDir = path;
    } else if ([sender isEqualTo:_autoPkgRecipeRepoDir] && validFolder(sender)) {
        _defaults.autoPkgRecipeRepoDir = path;
    } else if ([sender isEqualTo:_autoPkgRecipeOverridesDir] && validFolder(sender)){
        _defaults.autoPkgRecipeOverridesDir = path;
    }
}

- (void)enableFolders
{
    void (^enableForlderButton)(NSString *, NSButton *) = ^(NSString *path, NSButton *button) {
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
            button.enabled = YES;
        } else {
            DevLog(@"Could not locate %@ disabling 'Open Folder' button", path );
            button.enabled = NO;
        }
    };

    enableForlderButton(_defaults.autoPkgRecipeRepoDir ?: @"~/Library/AutoPkg/RecipeRepos".stringByExpandingTildeInPath,
                        _openAutoPkgRecipeReposFolderButton);

    enableForlderButton(_defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides".stringByExpandingTildeInPath,
                        _openAutoPkgRecipeOverridesFolderButton);

    enableForlderButton(_defaults.autoPkgCacheDir ?: @"~/Library/AutoPkg/Cache".stringByExpandingTildeInPath,
                        _openAutoPkgCacheFolderButton);
}

#pragma mark - Util
- (void)openFolderAtPath:(NSString *)path withDescription:(NSString *)folderDescription {

    DevLog(@"Opening %@ folder...", folderDescription);
    BOOL isDir;

    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        NSURL *autoPkgCacheFolderURL = [NSURL fileURLWithPath:path];
        [[NSWorkspace sharedWorkspace] openURL:autoPkgCacheFolderURL];
    } else {
        NSLog(@"%@ does not exist.", path);
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];

        NSString *messageTextFormat = NSLocalizedString(@"Cannot find the %@ folder.", @"alert message when a folder is not located");
        alert.messageText = quick_formatString(messageTextFormat, folderDescription);

        NSString *infoTextFormat = NSLocalizedString(@"%@ could not find the %@ folder located in %@. Please verify that this folder exists.", @"alert informativeText when a folder can't be located");

        alert.informativeText = quick_formatString(infoTextFormat, kLGApplicationName,  path);

        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:self.modalWindow
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}
@end
