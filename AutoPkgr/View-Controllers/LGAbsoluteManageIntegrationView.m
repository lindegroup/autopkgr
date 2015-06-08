//
//  LGAbsoluteManageIntegrationView.m
//  AutoPkgr
//
//  Created by Eldon on 6/7/15.
//  Copyright (c) 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGAbsoluteManageIntegrationView.h"
#import "LGAbsoluteManageIntegration.h"

@interface LGAbsoluteManageIntegrationView ()
@property (weak) IBOutlet NSButton *enableExternalUploadBT;

@end

@implementation LGAbsoluteManageIntegrationView

- (void)awakeFromNib {
    _enableExternalUploadBT.state = [LGAbsoluteManageDefaults new].AllowURLSDPackageImport;
}

- (IBAction)enableExternalSDPackageUpload:(NSButton *)sender
{
    [LGAbsoluteManageDefaults new].AllowURLSDPackageImport = sender.state;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

@end
