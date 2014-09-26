//
//  LGJSSAddon.m
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGJSSAddon.h"
#import "LGAutopkgr.h"


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
}

-(void)awakeFromNib
{
    _defaults = [LGDefaults standardUserDefaults];
    
    if (_defaults.JSSAPIUsername) _jssAPIUsernameTF.stringValue = _defaults.JSSAPIUsername;
    if (_defaults.JSSAPIPassword) _jssAPIPasswordTF.stringValue = _defaults.JSSAPIPassword;
    if (_defaults.JSSURL) _jssURLTF.stringValue = _defaults.JSSURL;
}

#pragma mark - IBActions
- (IBAction)updateJSSUsername:(id)sender
{
    if (![_jssAPIUsernameTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIUsername = _jssAPIUsernameTF.stringValue;
    }
}

-(IBAction)updaetJSSPassword:(id)sender
{
    if (![_jssAPIPasswordTF.stringValue isEqualToString:@""]) {
        _defaults.JSSAPIPassword = _jssAPIPasswordTF.stringValue;
    }
}

-(IBAction)updateJSSURL:(id)sender
{
    if (![_jssURLTF.stringValue isEqualToString:@""]) {
        _defaults.JSSURL = _jssURLTF.stringValue;
    }
}

-(void)checkCredentials:(id)sender
{
    [self startStatusUpdate];
    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        sleep(2);
        [self stopStatusUpdate:nil];
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