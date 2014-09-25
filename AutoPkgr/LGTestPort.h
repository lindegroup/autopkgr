//
//  LGTestPort.h
//  AutoPkgr
//
//  Created by Josh Senick on 7/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGTestPort : NSObject <NSStreamDelegate>

- (void)testHost:(NSHost *)host withPort:(NSInteger)port;

@end
