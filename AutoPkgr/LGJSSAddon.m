//
//  LGJSSAddon.m
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGJSSAddon.h"
#import "LGAutopkgr.h"
#import "LGHTTPRequest.h"
#import "LGTestPort.h"
#import "LGInstaller.h"
#import "LGHostInfo.h"
#import "LGAutoPkgTask.h"
#import "LGJSSDistributionPointsPrefPanel.h"

#pragma mark - Class constants

@implementation LGJSSAddon {
    LGDefaults *_defaults;
    LGTestPort *_portTester;
    BOOL _serverReachable;
    BOOL _installRequestedDuringConnect;
    LGJSSDistributionPointsPrefPanel *_preferencePanel;
}

- (void)awakeFromNib
{
    if ([[[NSApplication sharedApplication] delegate] conformsToProtocol:@protocol(LGProgressDelegate)]) {
        _progressDelegate = (id)[[NSApplication sharedApplication] delegate];
    }

    _defaults = [LGDefaults standardUserDefaults];
    _installRequestedDuringConnect = NO;

    [self showInstallTabItems:NO];

    // Disable the Add / Remove distPoint buttons
    // until a row is selected
    [_jssEditDistPointBT setEnabled:NO];
    [_jssRemoveDistPointBT setEnabled:NO];

    [_jssInstallStatusLight setImage:[NSImage LGStatusNotInstalled]];
    if ([LGHostInfo jssAddonInstalled] && _defaults.JSSRepos) {
        [self showInstallTabItems:YES];
    } else {
        [_jssInstallButton setEnabled:YES];
        [_jssInstallStatusTF setStringValue:@"JSS AutoPkg Addon not installed."];
    }

    // .safeStringValue is a NSTextField category that you can pass a nil value into.
    _jssAPIUsernameTF.safeStringValue = _defaults.JSSAPIUsername;
    _jssAPIPasswordTF.safeStringValue = _defaults.JSSAPIPassword;
    _jssURLTF.safeStringValue = _defaults.JSSURL;

    [self updateJSSURL:nil];
    [_jssDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)updateJSSUsername:(id)sender
{
    [self evaluateRepoViability];
}

- (IBAction)updateJSSPassword:(id)sender
{
    [self evaluateRepoViability];
}

- (IBAction)updateJSSURL:(id)sender
{
    [self evaluateRepoViability];
    [self checkReachability];

    [_jssReloadServerBT setEnabled:_jssURLTF.safeStringValue ? YES : NO];
}

- (IBAction)reloadJSSServerInformation:(id)sender
{
    if (!_jssURLTF.safeStringValue) {
        return;
    }

    if (![LGHostInfo jssAddonInstalled]) {
        _installRequestedDuringConnect = YES;
        if ([self requiresInstall]) {
            return;
        }
    }

    [self startStatusUpdate];
    LGHTTPRequest *request = [[LGHTTPRequest alloc] init];
    [request retrieveDistributionPoints:_jssURLTF.stringValue
                               withUser:_jssAPIUsernameTF.stringValue
                            andPassword:_jssAPIPasswordTF.stringValue
                                  reply:^(NSDictionary *distributionPoints, NSError *error) {
                                      if (!error) {
                                          [self saveDefaults];
                                          [_jssStatusLight setImage:[NSImage LGStatusAvailable]];
                                      }

                                      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                          [self stopStatusUpdate:error];
                                           id distPoints = distributionPoints[@"distribution_point"];
                                           if (distPoints) {
                                               NSArray *cleanedArray = [self evaluateJSSRepoDictionaries:distPoints];
                                               if (cleanedArray) {
                                                   _defaults.JSSRepos = cleanedArray;
                                                   [_jssDistributionPointTableView reloadData];
                                               }
                                           }
                                      }];
                                  }];
}

- (IBAction)installJSSAddon:(id)sender
{
    NSLog(@"Installing the jss-autopkg-addon.");
    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = _progressDelegate;
    [_jssInstallButton setEnabled:NO];
    [installer installJSSAddon:^(NSError *error) {
        BOOL success = (error == nil);
        if (success) {
            NSString *message = [NSString stringWithFormat:@"Adding %@",kLGJSSDefaultRepo];
            NSLog(@"Adding default JSS recipe repository: %@", kLGJSSDefaultRepo);
            [_progressDelegate startProgressWithMessage:message];
            [LGAutoPkgTask repoAdd:kLGJSSDefaultRepo reply:^(NSError *error) {
                [_progressDelegate stopProgress:error];
                [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationReposModified
                                                                    object:nil];

                if (_installRequestedDuringConnect) {
                    _installRequestedDuringConnect = NO;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self reloadJSSServerInformation:self];
                    }];
                }
            }];
        }
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if (success) {
                [self showInstallTabItems:YES];
            }
        }];
    }];
}

#pragma mark - Progress
- (void)startStatusUpdate
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jssStatusLight setHidden:YES];
        [_jssStatusSpinner setHidden:NO];
        [_jssStatusSpinner startAnimation:self];
    }];
}

- (void)stopStatusUpdate:(NSError *)error
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [_jssStatusLight setHidden:NO];
        [_jssStatusSpinner setHidden:YES];
        [_jssStatusSpinner stopAnimation:self];
        if (error) {
            [_progressDelegate stopProgress:error];
            [_jssStatusLight setImage:[NSImage LGStatusUnavailable]];
        }
    }];
}

#pragma mark - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_defaults.JSSRepos count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *distributionPoint;

    if ([_defaults.JSSRepos count] >= row) {
        distributionPoint = _defaults.JSSRepos[row];
    };
    NSString *identifier = [tableColumn identifier];
    NSString *setObject = distributionPoint[identifier];

    // if the object is still nil, because the name is not set sub in the url key
    if (!setObject && [identifier isEqualToString:kLGJSSDistPointNameKey]) {
        setObject = distributionPoint[kLGJSSDistPointURLKey];
    }
    return setObject;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:_defaults.JSSRepos];
    NSMutableDictionary *distributionPoint = [NSMutableDictionary dictionaryWithDictionary:workingArray[row]];

    if (!distributionPoint[kLGJSSDistPointTypeKey]) {
        if (![tableColumn.identifier isEqualToString:kLGJSSDistPointPasswordKey]) {
            return;
        }
    }

    [distributionPoint setValue:object forKey:tableColumn.identifier];
    [workingArray replaceObjectAtIndex:row withObject:distributionPoint];

    _defaults.JSSRepos = [NSArray arrayWithArray:workingArray];
}

-(void)tableViewSelectionDidChange:(NSNotification *)notification{
    NSInteger row = [_jssDistributionPointTableView selectedRow];
    // If nothing in the table is selected the row value is -1 so
    if (row > -1) {
        [_jssRemoveDistPointBT setEnabled:YES];
        // If a type key is not set, then it's from a DP from
        // the jss server and not editable.
        if([[_defaults.JSSRepos objectAtIndex:row] objectForKey:@"type"]){
            [_jssEditDistPointBT setEnabled:YES];
        } else {
            [_jssEditDistPointBT setEnabled:NO];
        }
    } else {
        [_jssEditDistPointBT setEnabled:NO];
        [_jssRemoveDistPointBT setEnabled:NO];
    }
}

#pragma mark - Utility
- (void)checkReachability
{
    if (!_jssURLTF.safeStringValue) {
        return;
    }
    // If there's a currently processing _portTester nil it out
    if (_portTester) {
        _portTester = nil;
    }

    _portTester = [[LGTestPort alloc] init];
    [self startStatusUpdate];

    [_portTester testServerURL:_jssURLTF.safeStringValue reply:^(BOOL reachable, NSString *redirectedURL) {
        _serverReachable = reachable;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (redirectedURL) {
                _jssURLTF.safeStringValue = redirectedURL;
            }
            
            if (reachable && [_defaults.JSSURL isEqualToString:_jssURLTF.safeStringValue]) {
                _jssStatusLight.image = [NSImage LGStatusAvailable];
                DLog(@"The JSS is responding and API user credentials seem valid.");
            } else if (reachable) {
                _jssStatusLight.image = [NSImage LGStatusPartiallyAvailable];
                DLog(@"The JSS is responding, but API user credentials don't seem valid.");
            } else {
                _jssStatusLight.image = [NSImage LGStatusUnavailable];
                DLog(@"The JSS is not reachable. Check your network connection and verify the JSS URL and port.");
            }
            // No need to keep this around so nil it out.
            _portTester = nil;
        }];
        [self stopStatusUpdate:nil];
    }];
}

- (NSArray *)evaluateJSSRepoDictionaries:(id)distPoints
{
    NSArray *dictArray;
    NSMutableArray *newRepos;

    // If there is just one ditribution point distPoint will be a dictionary entry
    // and we need to normalize it here by wrapping it in an array.
    if ([distPoints isKindOfClass:[NSDictionary class]]) {
        dictArray = @[ distPoints ];
    }
    // If there are more then one entries distPoint will be an array, so pass it along.
    else if ([distPoints isKindOfClass:[NSArray class]]) {
        dictArray = distPoints;
    }

    // If the "type" key is not set for the DP then it's auto detected via the server
    // and we'll strip them out here.
    LGDefaults *defaults = [LGDefaults standardUserDefaults];
    NSPredicate *customDistPointsPredicate = [NSPredicate predicateWithFormat:@"not %K == nil", kLGJSSDistPointTypeKey];
    NSArray *customDistPoints = [defaults.JSSRepos filteredArrayUsingPredicate:customDistPointsPredicate];
    newRepos = [[NSMutableArray alloc] initWithArray:customDistPoints];

    if (dictArray) {
        for (NSDictionary *repo in dictArray) {
            if (!repo[kLGJSSDistPointPasswordKey]) {
                NSString *name = repo[kLGJSSDistPointNameKey];
                NSString *password = [self promptForSharePassword:name];
                if (password && ![password isEqualToString:@""]) {
                    [newRepos addObject:@{ kLGJSSDistPointNameKey : name,
                                           kLGJSSDistPointPasswordKey : password }];
                }
            } else {
                [newRepos addObject:repo];
            }
        }
    }

    return [NSArray arrayWithArray:newRepos];
}

- (void)evaluateRepoViability
{
    // if all settings have been removed clear out the JSS_REPOS key too
    if (!_jssAPIPasswordTF.safeStringValue && !_jssAPIUsernameTF.safeStringValue && !_jssURLTF.safeStringValue) {
        _defaults.JSSRepos = nil;
        [self saveDefaults];
        [self showInstallTabItems:NO];
        [_jssStatusLight setImage:[NSImage LGStatusNone]];
    } else if (![_defaults.JSSAPIPassword isEqualToString:_jssAPIPasswordTF.safeStringValue] || ![_defaults.JSSAPIUsername isEqualToString:_jssAPIUsernameTF.safeStringValue] || ![_defaults.JSSURL isEqualToString:_jssURLTF.safeStringValue]) {
        // Update server status
        if ([_jssStatusLight.image isEqualTo:[NSImage LGStatusAvailable]]) {
            [_jssStatusLight setImage:[NSImage LGStatusPartiallyAvailable]];
        }

        // Show installer status
        [self showInstallTabItems:YES];
    }

    [_jssDistributionPointTableView reloadData];
}

- (void)showInstallTabItems:(BOOL)show
{
    // Show installer status
    [_jssInstallStatusLight setHidden:!show];
    [_jssInstallStatusTF setHidden:!show];
    [_jssInstallButton setHidden:!show];
    if (show) {
        NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
        [bgQueue addOperationWithBlock:^{
            BOOL updateAvailable = [LGHostInfo jssAddonUpdateAvailable];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [_jssInstallButton setEnabled:updateAvailable];
                if (updateAvailable) {
                    NSLog(@"An update is available for the jss-autopkg-addon.");
                    _jssInstallButton.title = @"Update JSS AutoPkg Addon";
                    _jssInstallStatusTF.stringValue = kLGJSSAutoPkgAddonUpdateAvailableLabel;
                    _jssInstallStatusLight.image = [NSImage LGStatusUpdateAvailable];
                } else {
                    NSLog(@"The jss-autopkg-addon is up to date.");
                    _jssInstallButton.title = @"Install JSS AutoPkg Addon";
                    _jssInstallStatusTF.stringValue = kLGJSSAutoPkgAddonInstalledLabel;
                    _jssInstallStatusLight.image = [NSImage LGStatusUpToDate];
                }
            }];
        }];
    }
}

- (void)saveDefaults
{
    _defaults.JSSAPIPassword = _jssAPIPasswordTF.safeStringValue;
    _defaults.JSSAPIUsername = _jssAPIUsernameTF.safeStringValue;
    _defaults.JSSURL = _jssURLTF.safeStringValue;
}

- (NSString *)promptForSharePassword:(NSString *)shareName
{
    NSLog(@"Prompting for password for distribution point: %@", shareName);
    NSString *password;
    NSString *alertString = [NSString stringWithFormat:@"Please enter read/write password for the %@ distribution point.", shareName];
    NSAlert *alert = [NSAlert alertWithMessageText:alertString
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];

    NSSecureTextField *input = [[NSSecureTextField alloc] init];
    [input setFrame:NSMakeRect(0, 0, 300, 24)];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        password = [input stringValue];
        if (!password || [password isEqualToString:@""]) {
            return [self promptForSharePassword:shareName];
        }
    }

    return password;
}

- (BOOL)requiresInstall
{
    BOOL required = NO;

    if (![LGHostInfo jssAddonInstalled]) {
        NSLog(@"Prompting for jss-autopkg-addon installation.");
        NSAlert *alert = [NSAlert alertWithMessageText:@"Install JSS AutoPkg Addon?"
                                         defaultButton:@"Install"
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"The JSS AutoPkg Addon is not currently installed. Would you like to install it now?"];

        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            [self installJSSAddon:nil];
        } else {
            _installRequestedDuringConnect = NO;
            NSLog(@"Installation of jss-autopkg-addon was canceled.");
        }
        return YES;
    }
    return required;
}

#pragma mark - Table View Contextual menu
- (NSMenu *)contextualMenuForDistributionPoint:(NSDictionary *)distPoint
{
    NSMenu *menu = [[NSMenu alloc] init];

    if (distPoint) {
        if (distPoint[kLGJSSDistPointTypeKey]) {
            NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit Distribution Point" action:@selector(editDistributionPoint:) keyEquivalent:@""];
            editItem.target = self;
            editItem.representedObject = distPoint;
            [menu addItem:editItem];
        }

        NSString *name = distPoint[kLGJSSDistPointNameKey] ?: distPoint[kLGJSSDistPointURLKey];
        NSString *removeString = [NSString stringWithFormat:@"Remove %@", name];
        NSMenuItem *removeItem = [[NSMenuItem alloc] initWithTitle:removeString action:@selector(removeDistributionPoint:) keyEquivalent:@""];
        removeItem.target = self;
        removeItem.representedObject = distPoint;
        [menu addItem:removeItem];
    } else {
        NSMenuItem *addItem = [[NSMenuItem alloc] initWithTitle:@"Add New Distribution Point" action:@selector(addDistributionPoint:) keyEquivalent:@""];
        addItem.target = self;
        [menu addItem:addItem];
    }

    return menu;
}

#pragma mark - JSS Distribution Point Preference Panel
- (void)addDistributionPoint:(id)sender
{

    if (!_preferencePanel) {
        _preferencePanel = [[LGJSSDistributionPointsPrefPanel alloc] init];
    }

    [NSApp beginSheet:_preferencePanel.window modalForWindow:_modalWindow modalDelegate:self didEndSelector:@selector(didClosePreferencePanel) contextInfo:nil];
}

- (void)removeDistributionPoint:(id)sender
{
    NSDictionary *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    } else {
        NSInteger row = _jssDistributionPointTableView.selectedRow;
        if (row > -1) {
            distPoint = _defaults.JSSRepos[row];
        }
    }

    NSMutableArray *workingArray = [[NSMutableArray alloc] initWithArray:_defaults.JSSRepos];
    [workingArray removeObject:distPoint];
    _defaults.JSSRepos = [NSArray arrayWithArray:workingArray];
    [_jssDistributionPointTableView reloadData];
}

- (void)editDistributionPoint:(id)sender
{

    NSDictionary *distPoint = nil;
    if ([sender isKindOfClass:[NSMenuItem class]]) {
        distPoint = [(NSMenuItem *)sender representedObject];
    } else {
        NSInteger row = _jssDistributionPointTableView.selectedRow;
        if (row > -1) {
            distPoint = _defaults.JSSRepos[row];
        }
    }

    if (distPoint && distPoint[kLGJSSDistPointTypeKey]) {
        if (!_preferencePanel) {
            _preferencePanel = [[LGJSSDistributionPointsPrefPanel alloc] initWithDistPointDictionary:distPoint];
        }

        [NSApp beginSheet:_preferencePanel.window modalForWindow:_modalWindow modalDelegate:self didEndSelector:@selector(didClosePreferencePanel) contextInfo:nil];
    }
}

- (void)didClosePreferencePanel
{
    if (![NSThread isMainThread]) {
        return [self performSelectorOnMainThread:@selector(didClosePreferencePanel) withObject:self waitUntilDone:NO];
    }

    [_preferencePanel.window close];
    _preferencePanel = nil;
    [_jssDistributionPointTableView reloadData];
}
@end
