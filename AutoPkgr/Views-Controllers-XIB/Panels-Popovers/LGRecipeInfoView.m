//
//  LGRecipeInfoView.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/19/15.
//  Copyright 2015 Eldon Ahrold.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGRecipeInfoView.h"
#import "LGAutoPkgRecipe.h"
#import "NSTextField+safeStringValue.h"

@interface LGRecipeInfoView ()
@property (weak) IBOutlet NSTextField *nameTF;
@property (weak) IBOutlet NSTextField *identifierTF;
@property (weak) IBOutlet NSTextField *parentRecipesTF;
@property (weak) IBOutlet NSTextField *filePathTF;
@property (weak) IBOutlet NSTextField *hasCheckPhaseTF;
@property (weak) IBOutlet NSTextField *buildsPackageTF;
@property (unsafe_unretained) IBOutlet NSTextView *descriptionTextView;

@property (weak) IBOutlet NSTextField *minimumVersionTF;
@end

@implementation LGRecipeInfoView {
    LGAutoPkgRecipe *_recipe;
}

- (instancetype)initWithRecipe:(LGAutoPkgRecipe *)recipe {
    if (self = [self initWithNibName:NSStringFromClass([self class]) bundle:[NSBundle mainBundle]]){
        _recipe = recipe;
    }
    return self;
}

- (void)awakeFromNib {
    /* Since the recipe description can be rather long, we use
     * we're using a textView with scrolling capabilities */
    _descriptionTextView.backgroundColor = [NSColor clearColor];

    NSMutableDictionary *attrs = @{NSFontAttributeName : [NSFont systemFontOfSize:11.0]}.mutableCopy;
    NSString *description = _recipe.Description;
    if (!description) {
        [attrs setObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
        description = @"<No description provided>";
    }
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:description
                                                                      attributes:attrs];

    [_descriptionTextView.textStorage appendAttributedString:attrString];

    _nameTF.safe_stringValue = _recipe.Name;
    _identifierTF.safe_stringValue = _recipe.Identifier;

    _parentRecipesTF.safe_stringValue = [_recipe.ParentRecipes componentsJoinedByString:@"\n"];
    if (_recipe.isMissingParent) {
        _parentRecipesTF.textColor = [NSColor redColor];
    }

    _minimumVersionTF.safe_stringValue = _recipe.MinimumVersion;

    _filePathTF.safe_stringValue = [_recipe.FilePath stringByAbbreviatingWithTildeInPath];
    _filePathTF.toolTip = _filePathTF.safe_stringValue;

    _hasCheckPhaseTF.safe_stringValue = [self stringForBool:_recipe.hasCheckPhase];

    _buildsPackageTF.safe_stringValue = [self stringForBool:_recipe.buildsPackage];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

}

- (NSString *)stringForBool:(BOOL)value{
    return value ? @"True":@"False";
}
@end
