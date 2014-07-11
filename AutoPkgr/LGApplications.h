//
//  LGApplications.h
//  AutoPkgr
//
//  Created by Josh Senick on 7/10/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LGAutoPkgRunner.h"

@interface LGApplications : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate> {
    
    IBOutlet NSTableView *applicationTableView;
    
    NSArray *apps;
    NSArray *activeApps;
    LGAutoPkgRunner *pkgRunner;
}

- (void)writeRecipeList;
- (NSString *)getAppSupportDirectory;

@end
