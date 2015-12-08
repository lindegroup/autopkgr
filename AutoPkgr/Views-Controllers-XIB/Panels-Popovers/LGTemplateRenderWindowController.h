//
//  LGTemplateRenderPanel.h
//  AutoPkgr
//
//  Created by Eldon on 12/6/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "LGWindowController.h"
@class LGTemplateRenderWindowController;


@interface LGTemplateRenderWindowController : LGWindowController
@property (copy, nonatomic) NSDictionary *exampleData;


- (NSString *)templateString;
@end

