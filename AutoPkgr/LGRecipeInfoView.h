//
//  LGInfoView.h
//  AutoPkgr
//
//  Created by Eldon on 5/19/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class LGAutoPkgRecipe;

@interface LGRecipeInfoView : NSViewController

-(instancetype)initWithRecipe:(LGAutoPkgRecipe *)recipe;

@end
