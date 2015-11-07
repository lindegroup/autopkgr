//
//  LGFileWaveIntegrationView.m
//  AutoPkgr
//
//  Copyright 2015 Elliot Jordan.
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

#import "LGFileWaveIntegrationView.h"
#import "LGFileWaveIntegration.h"

@interface LGFileWaveIntegrationView ()
@property (weak) IBOutlet NSButton *enableExternalUploadBT;

@end

@implementation LGFileWaveIntegrationView

- (void)awakeFromNib {
    _enableExternalUploadBT.state = [LGFileWaveDefaults new].AllowURLSDPackageImport;
}

- (IBAction)enableExternalSDPackageUpload:(NSButton *)sender
{
    [LGFileWaveDefaults new].AllowURLSDPackageImport = sender.state;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

@end
