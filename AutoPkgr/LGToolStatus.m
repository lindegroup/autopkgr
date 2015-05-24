// LGToolsStatus.m
// 
// Copyright 2015 The Linde Group, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


#import "LGToolStatus.h"
#import "LGTool.h"

#import "LGAutoPkgr.h"
#import "LGGitHubJSONLoader.h"

NSString *const kLGToolAutoPkg = @"AutoPkg";
NSString *const kLGToolGit = @"Git";
NSString *const kLGToolJSSImporter = @"JSSImporter";

@interface LGTool ()
@property (copy, nonatomic, readwrite) NSString *name;
@property (copy, nonatomic, readwrite) NSString *installedVersion;
@property (copy, nonatomic, readwrite) NSString *remoteVersion;
@property (assign, nonatomic, readwrite) LGToolInstallStatus status;
@end


@implementation LGToolStatus

- (void)allToolsStatus:(void (^)(NSArray *tools))complete
{
    [[NSOperationQueue new] addOperationWithBlock:^{
        NSMutableArray *tools = [NSMutableArray arrayWithCapacity:3];
        // AutoPkg
        LGTool *autoPkgTool = nil;
        if((autoPkgTool = [LGAutoPkgTool new])){
            [tools addObject:autoPkgTool];
        }

        // Git
        LGTool *gitTool = nil;
        if((gitTool = [LGGitTool new])){
            [tools addObject:gitTool];
        }

        // JSSImporter
        LGTool *jssImporterTool = nil;
        if((jssImporterTool = [LGJSSImporterTool new])){
            [tools addObject:jssImporterTool];
        }

        complete([tools copy]);
    }];
}

#pragma mark - Class Methods
+ (BOOL)requiredItemsInstalled {
    return ([LGAutoPkgTool isInstalled] &&
            [LGGitTool isInstalled]);
}

+ (void)displayRequirementsAlertOnWindow:(NSWindow *)window
{
    NSAlert *alert =[NSAlert alertWithMessageText:@"Required components not installed."
                                    defaultButton:@"OK"
                                  alternateButton:nil
                                      otherButton:nil
                        informativeTextWithFormat:@"AutoPkgr requires both AutoPkg and Git. Please install both before proceeding."];

    [alert beginSheetModalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}


@end