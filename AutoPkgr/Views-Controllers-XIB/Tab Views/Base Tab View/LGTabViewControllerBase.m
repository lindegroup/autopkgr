//
//  LGTabViewControllerBase.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 5/20/15.
//  Copyright 2015-2016 The Linde Group, Inc.
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

#import "LGTabViewControllerBase.h"

@interface LGTabViewControllerBase ()

@end

@implementation LGTabViewControllerBase

- (instancetype)init {
    return (self = [super initWithNibName:NSStringFromClass([self class]) bundle:nil]);
}

- (instancetype)initWithProgressDelegate:(id<LGProgressDelegate>)progressDelegate {
    if (self = [self init]) {
        _progressDelegate = progressDelegate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}


@end
