//
//  LGAutoPkgrHelperConnection.h
//  AutoPkgr
//
//  Created by Eldon on 7/28/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGAutoPkgrHelperConnection : NSObject

@property (atomic, strong, readonly) NSXPCConnection * connection;
-(void)connectToHelper;
@end
