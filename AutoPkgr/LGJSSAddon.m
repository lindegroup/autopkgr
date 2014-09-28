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

#pragma mark - LGDefaults extensions for JSS Addon Interface
@interface LGDefaults (JSSAddon)
@property (copy, nonatomic) NSString* JSSURL;
@property (copy, nonatomic) NSString* JSSAPIUsername;
@property (copy, nonatomic) NSString* JSSAPIPassword;
@property (copy, nonatomic) NSArray* JSSRepos;
@end


@implementation LGJSSAddon 
{
    LGDefaults *_defaults;
    LGHTTPRequest *_reachableTester;
}

-(void)awakeFromNib
{
    _defaults = [LGDefaults standardUserDefaults];
    
    if (_defaults.JSSAPIUsername) _jssAPIUsernameTF.stringValue = _defaults.JSSAPIUsername;
    if (_defaults.JSSAPIPassword) _jssAPIPasswordTF.stringValue = _defaults.JSSAPIPassword;
    if (_defaults.JSSURL) _jssURLTF.stringValue = _defaults.JSSURL;
    [_jssDistributionPointTableView reloadData];
    _reachableTester = [[LGHTTPRequest alloc] init];
    [self refreshReachability];
}

- (void)refreshReachability
{
    [_reachableTester checkReachabilityOfServer:_jssURLTF.stringValue reachable:^(BOOL reachable) {
        if (reachable) {
            [_jssStatusLight setImage:[NSImage imageNamed:@"NSStatusAvailable"]];
        } else {
            [_jssStatusLight setImage:[NSImage imageNamed:@"NSStatusUnavailable"]];
        }
    }];
    
}
#pragma mark - IBActions
- (IBAction)updateJSSUsername:(id)sender
{
    if (![_jssAPIUsernameTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIUsername = _jssAPIUsernameTF.stringValue;
    }
    [_jssDistributionPointTableView reloadData];
}

-(IBAction)updaetJSSPassword:(id)sender
{
    if (![_jssAPIPasswordTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIPassword = _jssAPIPasswordTF.stringValue;
    }
    [_jssDistributionPointTableView reloadData];
}

-(IBAction)updateJSSURL:(id)sender
{
    if (![_jssURLTF.stringValue isEqualToString:@""]) {
        _defaults.JSSURL = _jssURLTF.stringValue;
        [self refreshReachability];
    }
    [_jssDistributionPointTableView reloadData];
}

-(IBAction)reloadJSSServerInformation:(id)sender
{
    [self startStatusUpdate];
    [LGHTTPRequest retrieveDistributionPoints:_jssURLTF.stringValue
                                  withUser:_jssAPIUsernameTF.stringValue
                               andPassword:_jssAPIPasswordTF.stringValue reply:^(NSDictionary *distributionPoints, NSError *error) {
                                   [self stopStatusUpdate:nil];
                                   
                                   NSArray *array = distributionPoints[@"distribution_point"];
                                   if (array) {
                                       NSArray *cleanedArray = [self evaluateJSSRepoDictionaries:array];
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
        distributionPoint = [_defaults.JSSRepos objectAtIndex:row];
    };
    NSString *identifier = [tableColumn identifier];
    return distributionPoint[identifier];
}

#pragma mark - Utility
- (NSArray *)evaluateJSSRepoDictionaries:(NSArray *)dictArray
{
    NSMutableArray *newRepos = [[NSMutableArray alloc] init];
    for (NSDictionary *repo in dictArray) {
        if (!repo[@"password"]) {
            NSString *name = repo[@"name"];
            NSString *password = [self promptForPasswordForShare:name];
            if (password) {
                [newRepos addObject:@{@"name": name, @"password":password}];
            }
        } else {
            [newRepos addObject:repo];
        }
    }
    
    return [NSArray arrayWithArray:newRepos];
}

- (NSString *)promptForPasswordForShare:(NSString *)share
{
    NSString *alertString = [NSString stringWithFormat:@"Please enter password for %@",share];
    NSAlert *alert = [NSAlert alertWithMessageText:alertString
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:@""];
    
    NSSecureTextField *input = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        return [input stringValue];
    }
    return nil;
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