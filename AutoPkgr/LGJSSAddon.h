//
//  LGJSSAddon.h
//  AutoPkgr
//
//  Created by Eldon on 9/25/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGDefaults.h"
#import "LGProgressDelegate.h"

@interface LGJSSAddon : NSObject <NSTableViewDataSource>

@property (strong) IBOutlet NSTableView *jssDistributionPointTableView;
@property (weak) IBOutlet NSTextField *jssURLTF;
@property (weak) IBOutlet NSTextField *jssAPIUsernameTF;
@property (weak) IBOutlet NSTextField *jssAPIPasswordTF;
@property (weak) IBOutlet NSButton *jssReloadServerBT;
@property (weak) IBOutlet NSProgressIndicator *jssStatusSpinner;
@property (weak) IBOutlet NSImageView *jssStatusLight;

@end


#pragma mark - LGDefaults extensions for JSS Addon Interface
@interface LGDefaults (JSSAddon)

@property (copy, nonatomic) NSString* JSSURL;
@property (copy, nonatomic) NSString* JSSAPIUsername;
@property (copy, nonatomic) NSString* JSSAPIPassword;
@property (copy, nonatomic) NSArray* JSSRepos;

@end