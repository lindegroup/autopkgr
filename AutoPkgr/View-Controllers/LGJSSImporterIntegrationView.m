//
//  LGJSSImporterIntegrationView.h
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGJSSImporterIntegrationView.h"

#import "LGAutopkgr.h"
#import "LGAutoPkgTask.h"
#import "LGHTTPRequest.h"
#import "LGHostInfo.h"
#import "LGInstaller.h"
#import "LGJSSDistributionPointsPrefPanel.h"
#import "LGJSSImporterIntegration.h"
#import "LGServerCredentials.h"
#import "LGTableView.h"
#import "LGTestPort.h"

#pragma mark - Class constants

static NSPredicate *jdsFilterPredicate()
{
    static dispatch_once_t onceToken;
    __strong static NSPredicate *predicate = nil;
    dispatch_once(&onceToken, ^{
        predicate = [NSPredicate predicateWithFormat:@"not (type == 'JDS')"];
    });
    return predicate;
}

@implementation LGJSSImporterIntegrationView {
    LGJSSImporterDefaults *_defaults;
    LGTestPort *_portTester;
    LGJSSDistributionPointsPrefPanel *_preferencePanel;

    BOOL _serverReachable;
}

- (void)awakeFromNib
{

    _defaults = [LGJSSImporterDefaults new];

    // Disable the Add / Remove distPoint buttons
    // until a row is selected
    [_jssEditDistPointBT setEnabled:NO];
    [_jssRemoveDistPointBT setEnabled:NO];

    _jssUseMasterJDS.state = [_defaults.JSSRepos containsObject:@{ @"type" : @"JDS" }];

    // .safeStringValue is a NSTextField category that you can pass a nil value into.
    _jssAPIUsernameTF.safeStringValue = _defaults.JSSAPIUsername;
    _jssAPIPasswordTF.safeStringValue = _defaults.JSSAPIPassword;
    _jssURLTF.safeStringValue = _defaults.JSSURL;

    _jssReloadServerBT.action = @selector(testCredentials:);
    _jssReloadServerBT.title = @"Verify";

    [_jssDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)credentialsChanged:(NSTextField *)sender
{
    if ([sender isEqualTo:_jssURLTF] && ![_defaults.JSSURL isEqualToString:sender.stringValue]) {
        // There have been reports that old style cloud hosted JSS
        // have an issue when the base url is double slashed. Though theoritically
        // it doesn't make sense, it's an easy enough fix to apply here by looking
        // for a trailing slash and simply removing that.
        NSString *url = sender.stringValue.trailingSlashRemoved;
        sender.stringValue = url;

        if (!_portTester) {
            _portTester = [[LGTestPort alloc] init];
        }
        [self startStatusUpdate];

        [_portTester testServerURL:url reply:^(BOOL reachable, NSString *redirect) {
            [self stopStatusUpdate:nil];
            // If we got a redirect, update the sender to the new url.
            if (redirect.length && ([url isEqualToString:redirect] == NO)) {
                sender.stringValue = redirect.trailingSlashRemoved;
            }
        }];
    }

    // if all settings have been removed clear out the JSS_REPOS key too.
    if (!_jssAPIPasswordTF.safeStringValue && !_jssAPIUsernameTF.safeStringValue && !_jssURLTF.safeStringValue) {
        _defaults.JSSRepos = nil;
        _jssStatusLight.image = [NSImage LGStatusNone];
        _jssStatusLight.hidden = YES;
        [self saveDefaults];

    } else if (![_defaults.JSSAPIPassword isEqualToString:_jssAPIPasswordTF.safeStringValue] || ![_defaults.JSSAPIUsername isEqualToString:_jssAPIUsernameTF.safeStringValue] || ![_defaults.JSSURL isEqualToString:_jssURLTF.safeStringValue]) {

        // Update server status and reset the target action to check credentials...
        _jssStatusLight.image = [NSImage LGStatusPartiallyAvailable];
        _jssReloadServerBT.action = @selector(testCredentials:);
        _jssReloadServerBT.title = @"Verify";
    }
}

- (IBAction)testCredentials:(id)sender
{
    [self startStatusUpdate];

    LGHTTPCredential *jssCredentials = [[LGHTTPCredential alloc] init];
    jssCredentials.server = _jssURLTF.stringValue;
    jssCredentials.user = _jssAPIUsernameTF.stringValue;
    jssCredentials.password = _jssAPIPasswordTF.stringValue;

    [jssCredentials checkCredentialsForPath:@"/JSSResource/distributionpoints" reply:^(LGHTTPCredential *aCredential, LGCredentialChallengeCode status, NSError *error) {
        switch (status) {
            case kLGCredentialChallengeSuccess:
                if (aCredential.sslTrustSetting == kLGSSLTrustStatusUnknown) {
                    [self confirmDisableSSLVerify];
                } else if (aCredential.sslTrustSetting & (kLGSSLTrustOSImplicitTrust | kLGSSLTrustUserExplicitTrust)){
                    _defaults.JSSVerifySSL = YES;
                } else {
                    _defaults.JSSVerifySSL = NO;
                }

                _defaults.jssCredentials = aCredential;
                [_jssStatusLight setImage:[NSImage LGStatusAvailable]];

                // Reassign
                _jssReloadServerBT.action = @selector(getDistributionPoints:);
                _jssReloadServerBT.title = @"Connect";

                break;
            case kLGCredentialsNotChallenged:
                [_jssStatusLight setImage:[NSImage LGStatusUnavailable]];
                NSLog(@"The credentials for the JSS were never challenged. please check that the url you've set is correct");
                break;
            default:
                break;
        }

        [self stopStatusUpdate:error];
    }];
}

- (IBAction)getDistributionPoints:(id)sender
{
    LGHTTPRequest *request = [[LGHTTPRequest alloc] init];
    [request retrieveDistributionPoints:_defaults.jssCredentials
                                  reply:^(NSDictionary *distributionPoints, NSError *error) {
                                      [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                                          if (!error) {
                                              [_jssStatusLight setImage:[NSImage LGStatusAvailable]];
                                          }

                                          [self stopStatusUpdate:error];
                                          NSArray *cleanedArray = [self evaluateJSSRepoDictionaries:distributionPoints];
                                          if (cleanedArray) {
                                              _defaults.JSSRepos = cleanedArray;
                                              [_jssDistributionPointTableView reloadData];
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
            [self.integration.progressDelegate stopProgress:error];
            [_jssStatusLight setImage:[NSImage LGStatusUnavailable]];
        }
    }];
}

#pragma mark - NSTableViewDataSource
- (NSArray *)filteredData
{
    return [_defaults.JSSRepos filteredArrayUsingPredicate:jdsFilterPredicate()];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [[self filteredData] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSDictionary *distributionPoint;

    if ([[self filteredData] count] >= row) {
        distributionPoint = [self filteredData][row];
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
    NSMutableArray *workingArray = [[self filteredData] mutableCopy];
    NSMutableDictionary *distributionPoint = [NSMutableDictionary dictionaryWithDictionary:workingArray[row]];

    if (!distributionPoint[kLGJSSDistPointTypeKey]) {
        if (![tableColumn.identifier isEqualToString:kLGJSSDistPointPasswordKey]) {
            return;
        }
    }

    [distributionPoint setValue:object forKey:tableColumn.identifier];
    [workingArray replaceObjectAtIndex:row withObject:distributionPoint];

    if (_jssUseMasterJDS.state) {
        [workingArray addObject:@{ @"type" : @"JDS" }];
    }
    _defaults.JSSRepos = [workingArray copy];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger row = [_jssDistributionPointTableView selectedRow];
    // If nothing in the table is selected the row value is -1 so
    if (row > -1) {
        [_jssRemoveDistPointBT setEnabled:YES];
        // If a type key is not set, then it's from a DP from
        // the jss server and not editable.
        if ([[_defaults.JSSRepos objectAtIndex:row] objectForKey:@"type"]) {
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
- (void)confirmDisableSSLVerify
{

    NSAlert *alert = [NSAlert alertWithMessageText:@"Unable to verify the SSL certificate." defaultButton:@"Keep SSL Verification" alternateButton:@"Disable SSL Verification" otherButton:nil informativeTextWithFormat:@"This is most likely due to the certificate being self signed. Choosing \"Disable SSL Verification\" may be required for JSSImporter to function properly."];

    if ([alert runModal] == NSModalResponseOK) {
        _defaults.JSSVerifySSL = YES;
    } else {
        _defaults.JSSVerifySSL = NO;
    }
}

- (NSArray *)evaluateJSSRepoDictionaries:(NSDictionary *)distributionPoints
{
    id distPoints;

    // If the object was parsed as an XML object the key we're looking for is
    // distribution_point. If the object is a JSON object the key is distribution_points
    if ((distPoints = distributionPoints[@"distribution_point"]) == nil && (distPoints = distributionPoints[@"distribution_points"]) == nil) {
        return nil;
    }

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

    NSPredicate *customDistPointsPredicate = [NSPredicate predicateWithFormat:@"not %K == nil", kLGJSSDistPointTypeKey];
    NSArray *customDistPoints = [_defaults.JSSRepos filteredArrayUsingPredicate:customDistPointsPredicate];

    newRepos = [[NSMutableArray alloc] initWithArray:customDistPoints];

    if (dictArray) {
        for (NSDictionary *repo in dictArray) {
            if (!repo[kLGJSSDistPointPasswordKey]) {
                NSString *name = repo[kLGJSSDistPointNameKey];
                NSString *password = [self promptForSharePassword:name];
                if (password.length) {
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
    NSString *messageText = @"Distribution Point Password Required";

    NSString *const infoText = @"Please enter read/write password for the \"%@\" distribution point. If you intend to configure manually just click \"Cancel\".";

    NSAlert *alert = [NSAlert alertWithMessageText:messageText
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:infoText, shareName];

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

#pragma mark - JSS Distribution Point Preference Panel
- (void)enableMasterJDS:(NSButton *)sender
{
    NSMutableArray *workingArray = [_defaults.JSSRepos mutableCopy];
    NSDictionary *JDSDict = @{ @"type" : @"JDS" };

    NSUInteger index = [workingArray indexOfObjectPassingTest:
                        ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                            return [dict[@"type"] isEqualToString:@"JDS"];
                        }];

    if (sender.state) {
        // Add JDS
        if (index != NSNotFound) {
            [workingArray replaceObjectAtIndex:index withObject:JDSDict];
        } else {
            [workingArray addObject:JDSDict];
        }
    } else {
        if (index != NSNotFound) {
            [workingArray removeObjectAtIndex:index];
        }
    }

    _defaults.JSSRepos = [workingArray copy];
}

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
            distPoint = [self filteredData][row];
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
        if (0 <= row) {
            distPoint = [self filteredData][row];
        }
    }

    if (distPoint && distPoint[kLGJSSDistPointTypeKey]) {
        if (!_preferencePanel) {
            _preferencePanel = [[LGJSSDistributionPointsPrefPanel alloc] initWithDistPointDictionary:distPoint];
        }

        [NSApp beginSheet:_preferencePanel.window
           modalForWindow:_modalWindow
            modalDelegate:self
           didEndSelector:@selector(didClosePreferencePanel) contextInfo:nil];
    }
}

#pragma mark - Panel didEnd Selectors
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
