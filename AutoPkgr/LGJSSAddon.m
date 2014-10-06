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

@implementation LGJSSAddon {
    LGDefaults *_defaults;
    LGTestPort *_portTester;
    BOOL _serverReachable;
}

- (void)awakeFromNib
{
    _defaults = [LGDefaults standardUserDefaults];

    NSImage *notInstalled = [NSImage imageNamed:@"NSStatusNone"];
    NSImage *updateAvaliable = [NSImage imageNamed:@"NSStatusPartiallyAvailable"];

    [_jssStatusLight setImage:notInstalled];
    [_jssInstallStatusLight setHidden:NO];

    if ([LGHostInfo jssAddonInstalled]) {
        [_jssInstallStatusLight setImage:updateAvaliable];
        [_jssInstallStatusLight setHidden:NO];
        NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
        [bgQueue addOperationWithBlock:^{
            BOOL updateAvaliable = [LGHostInfo jssAddonUpdateAvailable];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (updateAvaliable) {
                    _jssInstallStatusTF.stringValue = @"JSS AutoPkg update avaliable";
                    [_jssInstallButton setEnabled:YES];
                } else {
                    NSString *version = [LGHostInfo getJSSAddonVersion];
                    NSImage *image = [NSImage imageNamed:@"NSStatusAvailable"];
                    NSString *title = [NSString stringWithFormat:@"Version %@ installed",version];
                    
                    _jssInstallStatusLight.image = image;
                    _jssInstallButton.title = title ;

                }
            }];
        }];
    } else {
        [_jssInstallStatusLight setImage:notInstalled];
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

- (void)installJSSAddon:(id)sender
{
    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = [NSApp delegate];
    [installer installJSSAddon:^(NSError *error) {
        if (!error) {
            [[NSOperationQueue mainQueue]addOperationWithBlock:^{
                _jssInstallStatusTF.stringValue = @"JSS AutoPkg Addon is up to date.";
                _jssInstallStatusLight.image = [NSImage imageNamed:@"NSStatusAvailable"];
                [_jssReloadServerBT setEnabled:NO];
            }];
        }
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
    _portTester = [[LGTestPort alloc] init];
    [self startStatusUpdate];
    [_portTester testServerURL:_jssURLTF.safeStringValue reply:^(BOOL reachable) {
        _serverReachable = reachable;
        if (reachable) {
            [_jssStatusLight setImage:[NSImage imageNamed:@"NSStatusAvailable"]];
        } else {
            [_jssStatusLight setImage:[NSImage imageNamed:@"NSStatusUnavailable"]];
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
        NSAlert *alert = [NSAlert alertWithMessageText:@"Install autopkg-jss-addon?" defaultButton:@"Install" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"You have selected a recipe that requres installation of the autopkg-jss-addon, would you like to install it now?"];

        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            LGInstaller *installer = [[LGInstaller alloc] init];
            installer.progressDelegate = [NSApp delegate];
            [installer installJSSAddon:^(NSError *error) {}];
        }
        return YES;
    }
    return required;
}
@end
