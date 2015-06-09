//
//  NSOpenPanel+typeChooser.m
//  AutoPkgr
//
//  Created by Eldon on 6/7/15.
//  Copyright 2015 Eldon Ahrold
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

#import "NSOpenPanel+typeChooser.h"

@implementation NSOpenPanel (typeChooser)
+ (void)folderChooser_WithStartingPath:(NSString *)path modalWindow:(NSWindow *)window reply:(void (^)(NSString *))reply
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    panel.canChooseFiles = NO;

    // Enable the selection of directories in the dialog
    panel.canChooseDirectories = YES;

    // Enable the creation of directories in the dialog
    panel.canCreateDirectories = YES;

    // Disable multiple selection
    panel.allowsMultipleSelection = NO;

    // Set the prompt to "Choose" instead of "Open"
    panel.prompt = @"Choose";

    panel.directoryURL = [NSURL fileURLWithPath:path];

    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            BOOL isDir = NO;

            if (panel.URL.isFileURL) {
                // Verify that the file exists and is a directory
                if ([[NSFileManager defaultManager] fileExistsAtPath:panel.URL.path isDirectory:&isDir] && isDir) {
                    // Here we can be certain the URL exists and it is a directory
                    reply(panel.URL.path);
                }
            }
        }
        reply(nil);
    }];
}

+ (void)folderChooser_WithStartingPath:(NSString *)path reply:(void (^)(NSString *))reply {
    [self folderChooser_WithStartingPath:path modalWindow:nil reply:reply];
}

+ (void)executableChooser_WithStartingPath:(NSString *)path modalWindow:(NSWindow *)window reply:(void (^)(NSString *))reply {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    // Disable the selection of files in the dialog
    panel.canChooseFiles = YES;

    // Enable the selection of directories in the dialog
    panel.canChooseDirectories = NO;

    // Enable the creation of directories in the dialog
    panel.canCreateDirectories = NO;

    // Disable multiple selection
    panel.allowsMultipleSelection = NO;

    // Set the prompt to "Choose" instead of "Open"
    panel.prompt = @"Choose";

    panel.directoryURL = [NSURL fileURLWithPath:path];

    [panel beginSheetModalForWindow:window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {

            if (panel.URL.isFileURL) {
                BOOL isDir;
                // Verify that the file exists is not a directory, and is executable.
                if (([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && !isDir) &&
                    ([[NSFileManager defaultManager] isExecutableFileAtPath:panel.URL.path])) {
                    reply(panel.URL.path);
                }
            }
        }
        reply(nil);
    }];
}

+(void)executableChooser_WithStartingPath:(NSString *)path reply:(void (^)(NSString *))reply {
    [self executableChooser_WithStartingPath:path modalWindow:nil reply:reply];
}


@end
