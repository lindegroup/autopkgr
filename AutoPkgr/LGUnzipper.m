//
//  LGUnzipper.m
//  AutoPkgr
//
//  Created by James Barclay on 6/29/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGUnzipper.h"

@implementation LGUnzipper

+ (BOOL)unzip:(NSString *)zipPath targetDir:(NSString *)targetDir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;

    // Remove the targetDir if it already exists
    BOOL isDir;
    if ([fm fileExistsAtPath:targetDir isDirectory:&isDir] && isDir) {
        NSLog(@"%@ already exists. Removing it.", targetDir);
        [fm removeItemAtPath:targetDir error:&error];

        if (error) {
            NSLog(@"An error occurred when attempting to remove %@. Error: %@.", targetDir, error);
        }
    }

    // Create the targetDir
    [fm createDirectoryAtPath:targetDir withIntermediateDirectories:NO
                         attributes:nil
                              error:&error];

    if (error) {
        NSLog(@"An error occurred when attempting to create tmp dir %@. Error: %@.", targetDir, error);
    }

    // Create unzip NSTask
    NSArray *args = [NSArray arrayWithObjects:@"-u", @"-d", targetDir, zipPath, nil];
    NSTask *unzipTask = [[NSTask alloc] init];
    NSPipe *pipe = [NSPipe pipe];
    [unzipTask setStandardOutput:pipe];
    [unzipTask setLaunchPath:@"/usr/bin/unzip"];
    [unzipTask setCurrentDirectoryPath:targetDir];
    [unzipTask setArguments:args];
    [unzipTask launch];
    [unzipTask waitUntilExit];

    if ([unzipTask terminationStatus] == 0) {
        return YES;
    }

    return NO;
}

@end
