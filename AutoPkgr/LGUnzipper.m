//
//  LGUnzipper.m
//  AutoPkgr
//
//  Created by James Barclay on 6/29/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGUnzipper.h"

@implementation LGUnzipper

- (BOOL)unzip:(NSString *)zipPath targetDir:(NSString *)targetDir
{
    NSFileManager* fm = [NSFileManager defaultManager];

    NSError *error;
    [fm createDirectoryAtPath:targetDir withIntermediateDirectories:NO
                   attributes:nil error:&error];

    if (error) {
        NSLog(@"Error when attempting to create tmp dir %@. Error: %@.", targetDir, error);
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
