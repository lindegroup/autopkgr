//
//  LGInfoView.m
//  AutoPkgr
//
//  Created by Eldon on 5/19/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGRecipeInfoView.h"
#import "LGAutoPkgRecipe.h"

@interface LGRecipeInfoView ()
@property (weak) IBOutlet NSTextField *nameTF;
@property (weak) IBOutlet NSTextField *identifierTF;
@property (weak) IBOutlet NSTextField *descriptionTF;
@property (weak) IBOutlet NSTextField *parentRecipesTF;
@property (weak) IBOutlet NSTextField *filePathTF;
@property (weak) IBOutlet NSTextField *hasCheckPhaseTF;
@property (weak) IBOutlet NSTextField *buildsPackageTF;

@property (weak) IBOutlet NSTextField *minimumVersionTF;
@end

@implementation LGRecipeInfoView {
    LGAutoPkgRecipe *_recipe;
}

-(instancetype)initWithRecipe:(LGAutoPkgRecipe *)recipe {
    if (self = [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]]){
        _recipe = recipe;
    }
    return self;
}

- (void)awakeFromNib {
    _nameTF.stringValue = _recipe.Name;
    _identifierTF.stringValue = _recipe.Identifier;
    _parentRecipesTF.stringValue = [_recipe.ParentRecipes componentsJoinedByString:@"\n"] ?: @"";
    _descriptionTF.stringValue = _recipe.Description ?: @"";
    _minimumVersionTF.stringValue = _recipe.MinimumVersion ?: @"";
    _filePathTF.stringValue = [_recipe.FilePath stringByAbbreviatingWithTildeInPath];

    _hasCheckPhaseTF.stringValue = [self stringForBool:_recipe.hasCheckPhase];
    _buildsPackageTF.stringValue = [self stringForBool:_recipe.buildsPackage];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

}

- (NSString *)stringForBool:(BOOL)value{
    return value ? @"True":@"False";
}
@end
