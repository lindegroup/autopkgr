//
//  LGPopularRepositories.h
//  AutoPkgr
//
//  Created by Josh Senick on 7/9/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGAutoPkgRunner.h"

@interface LGPopularRepositories : NSObject <NSApplicationDelegate, NSTableViewDelegate, NSTableViewDataSource> {
    
    IBOutlet NSTableView *popularRepositoriesTableView;
    
    NSArray *popularRepos;
    NSArray *activeRepos;
    LGAutoPkgRunner *pkgRunner;
}

- (void)reload;

@end
