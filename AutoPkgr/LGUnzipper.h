//
//  LGUnzipper.h
//  AutoPkgr
//
//  Created by James Barclay on 6/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGUnzipper : NSObject

- (BOOL)unzip:(NSString *)zipPath targetDir:(NSString *)targetDir;

@end
