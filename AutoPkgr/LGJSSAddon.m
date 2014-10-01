//
//  LGJSSAddon.m
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGJSSAddon.h"
#import "LGAutopkgr.h"
#import "LGHTTPRequest.h"
#import "LGTestPort.h"
#import "LGInstaller.h"
#import "LGHostInfo.h"


@implementation LGJSSAddon 
{
    LGDefaults *_defaults;
    LGTestPort *_portTester;
    BOOL _serverReachable;
}

-(void)awakeFromNib
{
    _defaults = [LGDefaults standardUserDefaults];
    [_jssStatusLight setImage:[NSImage imageNamed:@"NSStatusNone"]];
    if (_defaults.JSSAPIUsername) _jssAPIUsernameTF.stringValue = _defaults.JSSAPIUsername;
    if (_defaults.JSSAPIPassword) _jssAPIPasswordTF.stringValue = _defaults.JSSAPIPassword;
    if (_defaults.JSSURL) {
        _jssURLTF.stringValue = _defaults.JSSURL;
        [self checkReachability];
    }
    [self evaluateRepoViability];
    [_jssDistributionPointTableView reloadData];
}

#pragma mark - IBActions
- (IBAction)updateJSSUsername:(id)sender
{
    if ([_jssAPIUsernameTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIUsername = nil;
    } else {
        _defaults.JSSAPIUsername = _jssAPIUsernameTF.stringValue;
    }
    [self evaluateRepoViability];
}

-(IBAction)updateJSSPassword:(id)sender
{
    if ([_jssAPIPasswordTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIPassword = nil;
    } else {
        _defaults.JSSAPIPassword = _jssAPIPasswordTF.stringValue;
    }
    [self evaluateRepoViability];
}

-(IBAction)updateJSSURL:(id)sender
{
    if ([_jssURLTF.stringValue isEqualToString:@""]) {
        _defaults.JSSURL = nil;
    } else {
        _defaults.JSSURL = _jssURLTF.stringValue;
        [self checkReachability];
    }
    [self evaluateRepoViability];
}

-(IBAction)reloadJSSServerInformation:(id)sender
{
    if (!_serverReachable) {
        [self stopStatusUpdate:[LGError errorWithCode:kLGErrorTestingPort]];
        return;
    }
    
    [self startStatusUpdate];
    LGHTTPRequest *request = [[LGHTTPRequest alloc] init];
    [request retrieveDistributionPoints:_jssURLTF.stringValue
                               withUser:_jssAPIUsernameTF.stringValue
                            andPassword:_jssAPIPasswordTF.stringValue reply:^(NSDictionary *distributionPoints, NSError *error) {
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
            [NSApp presentError:error];
        }
    }];
}

#pragma mark - NSTableViewDataSource
-(NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
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

-(void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row{

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
    [_portTester testServerURL:_jssURLTF.stringValue reply:^(BOOL reachable) {
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
        dictArray = @[distPoints];
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
                    [newRepos addObject:@{@"name": name, @"password":password}];
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
    if (!_defaults.JSSAPIPassword &&
        !_defaults.JSSAPIUsername &&
        !_defaults.JSSURL) {
        _defaults.JSSRepos = nil;
    }
    [_jssDistributionPointTableView reloadData];
}

- (NSString *)promptForSharePassword:(NSString *)shareName
{
    NSString *password;
    NSString *alertString = [NSString stringWithFormat:@"Please enter read/write password for the %@ distribution point",shareName];
    NSAlert *alert = [NSAlert alertWithMessageText:alertString
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    
    NSSecureTextField *input = [[NSSecureTextField alloc]init];
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
+ (BOOL)requiresInstall:(NSArray *)recipeList
{
    BOOL required = NO;
    
    NSPredicate *jssAddonPredicate = [NSPredicate predicateWithFormat:@"SELF contains[cd] %@",@"jss"];
    if ([[recipeList filteredArrayUsingPredicate:jssAddonPredicate] count] &&
        ![LGHostInfo jssAddonInstalled]) {
        NSAlert *alert = [NSAlert alertWithMessageText:@"Install autopkg-jss-addon?" defaultButton:@"Install" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"You have selected a recipe that requres installation of the autopkg-jss-addon, would you like to install it now?"];
        
        NSInteger button = [alert runModal];
        if (button == NSAlertDefaultReturn) {
            LGInstaller *installer = [[LGInstaller alloc] init];
            required = ![installer runJSSAddonInstaller:nil];
        } else {
            required = YES;
        }
    }
    return required;
}
@end


#pragma mark - LGDefaults catagory implementation for JSS Addon Interface

@implementation LGDefaults (JSSAddon)
-(NSString *)JSSURL
{
    return [self autoPkgDomainObject:@"JSS_URL"];
}

-(void)setJSSURL:(NSString *)JSSURL{
    [self setAutoPkgDomainObject:JSSURL forKey:@"JSS_URL"];
}

#pragma mark -
-(NSString *)JSSAPIUsername
{
    return [self autoPkgDomainObject:@"API_USERNAME"];
}

-(void)setJSSAPIUsername:(NSString *)JSSAPIUsername
{
    [self setAutoPkgDomainObject:JSSAPIUsername forKey:@"API_USERNAME"];
}

#pragma mark -
-(NSString *)JSSAPIPassword
{
    return [self autoPkgDomainObject:@"API_PASSWORD"];
}

-(void)setJSSAPIPassword:(NSString *)JSSAPIPassword
{
    [self setAutoPkgDomainObject:JSSAPIPassword forKey:@"API_PASSWORD"];
}

#pragma mark -
-(NSArray *)JSSRepos
{
    return [self autoPkgDomainObject:@"JSS_REPOS"];
}

-(void)setJSSRepos:(NSArray *)JSSRepos
{
    [self setAutoPkgDomainObject:JSSRepos forKey:@"JSS_REPOS"];
}

@end