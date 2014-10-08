//
//  LGJSSAddon.m
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
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

#pragma mark - Class constants
NSString *defaultJSSRepo = @"https://github.com/sheagcraig/jss-recipes.git";


@implementation LGJSSAddon {
    LGDefaults *_defaults;
    LGTestPort *_portTester;
    BOOL _serverReachable;
}

- (void)awakeFromNib
{
    _defaults = [LGDefaults standardUserDefaults];

    [_jssInstallStatusLight setImage:[NSImage LGStatusNotInstalled]];
    [_jssInstallStatusLight setHidden:NO];

    if ([LGHostInfo jssAddonInstalled]) {
        [_jssInstallStatusLight setHidden:NO];
        NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
        [bgQueue addOperationWithBlock:^{
            BOOL updateAvaliable = [LGHostInfo jssAddonUpdateAvailable];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (updateAvaliable) {
                    _jssInstallStatusTF.stringValue = @"JSS AutoPkg update avaliable.";
                    [_jssInstallButton setEnabled:YES];
                    _jssInstallButton.image = [NSImage LGStatusUpdateAvaliable];
                } else {
                    NSString *version = [LGHostInfo getJSSAddonVersion];
                    NSString *title = [NSString stringWithFormat:@"Version %@ installed",version];
                    
                    _jssInstallStatusLight.image = [NSImage LGStatusUpToDate];
                    _jssInstallButton.title = title ;

                }
            }];
        }];
    } else {
        [_jssInstallButton setEnabled:YES];
        [_jssInstallButton setTitle:@"Install JSS AutoPkg Addon"];
        [_jssInstallStatusTF setStringValue:@"JSS AutoPkg Addon not installed."];
    }

    _jssAPIUsernameTF.safeStringValue = _defaults.JSSAPIUsername;
    _jssAPIPasswordTF.safeStringValue = _defaults.JSSAPIPassword;

    if (_defaults.JSSURL) {
        _jssURLTF.safeStringValue = _defaults.JSSURL;
        [self checkReachability];
    }

    [self evaluateRepoViability];
    [_jssDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)updateJSSUsername:(id)sender
{
    _defaults.JSSAPIUsername = _jssAPIUsernameTF.safeStringValue;
    [self evaluateRepoViability];
}

- (IBAction)updateJSSPassword:(id)sender
{
    _defaults.JSSAPIPassword = _jssAPIPasswordTF.safeStringValue;
    [self evaluateRepoViability];
}

- (IBAction)updateJSSURL:(id)sender
{
    _defaults.JSSURL = _jssURLTF.safeStringValue;
    [self checkReachability];
    [self evaluateRepoViability];
}

- (IBAction)reloadJSSServerInformation:(id)sender
{
    if (!_serverReachable) {
        [self stopStatusUpdate:[LGError errorWithCode:kLGErrorTestingPort]];
        return;
    }

    if ([self requiresInstall]) {
        return;
    }

    [self startStatusUpdate];
    LGHTTPRequest *request = [[LGHTTPRequest alloc] init];
    [request retrieveDistributionPoints:_jssURLTF.stringValue
                               withUser:_jssAPIUsernameTF.stringValue
                            andPassword:_jssAPIPasswordTF.stringValue
                                  reply:^(NSDictionary *distributionPoints, NSError *error) {
                                   [self stopStatusUpdate:error];
                                   
                                   id distPoints = distributionPoints[@"distribution_point"];
                                   if (distPoints) {
                                       NSArray *cleanedArray = [self evaluateJSSRepoDictionaries:distPoints];
                                       if ([cleanedArray count]) {
                                           _defaults.JSSRepos = cleanedArray;
                                           [_jssDistributionPointTableView reloadData];
                                       }
                                   }
                                  }];
}

- (IBAction)installJSSAddon:(id)sender
{
    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = [NSApp delegate];
    [_jssInstallButton setEnabled:NO];
    [installer installJSSAddon:^(NSError *error) {
        BOOL success = (error == nil);
        if (success) {
            [LGAutoPkgTask repoAdd:defaultJSSRepo reply:^(NSError *error) {
                if (error) {
                    NSLog(@"Problem adding the default jss-repo");
                    DLog(@"%@",error);
                }
            }];
        }
        [[NSOperationQueue mainQueue]addOperationWithBlock:^{
            if (success) {
                NSString *version = [LGHostInfo getJSSAddonVersion];
                NSString *title = [NSString stringWithFormat:@"Version %@ installed",version];
                _jssInstallStatusTF.stringValue = @"JSS AutoPkg Addon is up to date.";
                _jssInstallButton.title = title;
                _jssInstallStatusLight.image = [NSImage LGStatusUpToDate];
            }
            [_jssInstallButton setEnabled:success ? NO:YES];
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
            [[NSApp delegate] stopProgress:error];
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
    return distributionPoint[identifier];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{

    NSMutableArray *workingArray = [NSMutableArray arrayWithArray:_defaults.JSSRepos];
    NSMutableDictionary *distributionPoint = [NSMutableDictionary dictionaryWithDictionary:workingArray[row]];

    [distributionPoint setValue:object forKey:[tableColumn identifier]];
    [workingArray replaceObjectAtIndex:row withObject:distributionPoint];

    _defaults.JSSRepos = [NSArray arrayWithArray:workingArray];
}

#pragma mark - Utility
- (void)checkReachability
{
    // If there's a currently processing _portTester nil it out
    if (_portTester) {
        _portTester = nil;
    }

    _portTester = [[LGTestPort alloc] init];
    [self startStatusUpdate];
    [_portTester testServerURL:_jssURLTF.safeStringValue reply:^(BOOL reachable) {
        _serverReachable = reachable;
        if (reachable) {
            [_jssStatusLight setImage:[NSImage LGStatusAvaliable]];
        } else {
            [_jssStatusLight setImage:[NSImage LGStatusUnavaliable]];
        }
        [self stopStatusUpdate:nil];
        _portTester = nil;
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

    if (dictArray) {
        newRepos = [[NSMutableArray alloc] init];
        for (NSDictionary *repo in dictArray) {
            if (!repo[@"password"]) {
                NSString *name = repo[@"name"];
                NSString *password = [self promptForSharePassword:name];
                if (password) {
                    [newRepos addObject:@{ @"name" : name,
                                           @"password" : password }];
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
    if (!_defaults.JSSAPIPassword && !_defaults.JSSAPIUsername && !_defaults.JSSURL) {
        _defaults.JSSRepos = nil;
    }
    [_jssDistributionPointTableView reloadData];
}

- (NSString *)promptForSharePassword:(NSString *)shareName
{
    NSString *password;
    NSString *alertString = [NSString stringWithFormat:@"Please enter read/write password for the %@ distribution point", shareName];
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
    }
    return password;
}

#pragma mark - Class Methods
- (BOOL)requiresInstall
{
    BOOL required = NO;

    if (![LGHostInfo jssAddonInstalled]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Install JSS AutoPkg Addon?" defaultButton:@"Install" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"The JSS AutoPkg Addon is not currently installed, would you like to install it now?"];

        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            [self installJSSAddon:self];
        }

        return YES;
    }
    return required;
}
@end
