//
//  LGInstaller.m
//  AutoPkgr
//
//  Created by Eldon on 9/9/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
//

#import "LGInstaller.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGGitHubJSONLoader.h"

@implementation LGInstaller {
    NSString *_mountPoint;
}

- (void)installGit:(void (^)(NSError *error))reply
{
    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        NSError *error;
        [_progressDelegate startProgressWithMessage:@"Installing Git"];
        [self runGitInstaller:&error];
        [_progressDelegate stopProgress:error];
        reply(error);
    }];
}

- (BOOL)runGitInstaller:(NSError *__autoreleasing *)error
{
    // download pkg from google code (source forge is almost impossible to reach)
    [_progressDelegate updateProgress:@"Downloading Git..." progress:5.0];
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];

    // Get the latest Git PKG download URL
    NSString *downloadURL = [jsonLoader getGitDownloadURL];

    NSString *tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[downloadURL lastPathComponent]];

    [_progressDelegate updateProgress:@"Building Git installer package..." progress:25.0];
    // Download Git to the temporary directory
    if (![[NSFileManager defaultManager] fileExistsAtPath:tmpFile]) {
        NSData *gitDMG = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:downloadURL]];
        if (!gitDMG || ![gitDMG writeToFile:tmpFile atomically:YES]) {
            DLog(@"Could not write the Git installer disk iamge to the system path.");
            return [LGError errorWithCode:kLGErrorInstallGit error:error];
        }
    }

    // Open DMG
    BOOL RC = NO;
    [_progressDelegate updateProgress:@"Mounting Git disk image..." progress:50.0];
    if ([self mountDMG:tmpFile] && _mountPoint) {
        // install Pkg
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_mountPoint error:nil];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension == 'pkg'"];

        NSString *pkg = [[contents filteredArrayUsingPredicate:predicate] firstObject];
        NSString *asVolume = [_mountPoint stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];

        NSString *installCommand = [NSString stringWithFormat:@"/usr/sbin/installer -pkg %@ -target /", [asVolume stringByAppendingPathComponent:pkg]];
        DLog(@" %@", installCommand);
        [_progressDelegate updateProgress:@"Installing Git..." progress:75.0];
        RC = [self runCommandAsRoot:installCommand error:error];
    }

    if (RC) {
        // If the installer was performed from here
        // set the autopkg GIT_PATH key
        [[LGDefaults standardUserDefaults] setGitPath:@"/usr/local/git/bin/git"];
    }

    [_progressDelegate updateProgress:@"Unmounting Git disk image..." progress:100.0];
    [self unmountVolume];
    return RC;
}

- (BOOL)runAutoPkgInstaller:(NSError *__autoreleasing *)error
{
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];

    [_progressDelegate updateProgress:@"Downloading AutoPkg..." progress:5.0];
    // Get the latest AutoPkg PKG download URL
    NSString *downloadURL = [jsonLoader getLatestAutoPkgDownloadURL];

    // Get path for autopkg-x.x.x.pkg
    NSString *autoPkgPkg = [NSTemporaryDirectory() stringByAppendingPathComponent:[downloadURL lastPathComponent]];

    [_progressDelegate updateProgress:@"Building AutoPkg installer package..." progress:25.0];
    // Download AutoPkg to the temporary directory
    NSData *autoPkg = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:downloadURL]];
    [autoPkg writeToFile:autoPkgPkg atomically:YES];

    // Set the `installer` command
    NSString *command = [NSString stringWithFormat:@"/usr/sbin/installer -pkg %@ -target /", autoPkgPkg];

    // Install the AutoPkg PKG as root
    [_progressDelegate updateProgress:@"Installing AutoPkg..." progress:75.0];
    return [self runCommandAsRoot:command error:error];
    [_progressDelegate updateProgress:@"Installing AutoPkg..." progress:100.0];
}

- (void)installAutoPkg:(void (^)(NSError *error))reply
{
    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        NSError *error;
        [_progressDelegate startProgressWithMessage:@"Installing AutoPkg..."];
        [self runAutoPkgInstaller:&error];
        [_progressDelegate stopProgress:error];
        reply(error);
    }];
}

- (void)updateAutoPkgr:(void (^)(NSError *error))reply
{
    // possibly do what we need to with sparkle //
}

#pragma mark - Util Methods
- (BOOL)runCommandAsRoot:(NSString *)command error:(NSError *__autoreleasing *)error;
{
    // Super dirty hack, but way easier than
    // using Authorization Services
    NSDictionary *errorDict = [[NSDictionary alloc] init];
    NSString *script = [NSString stringWithFormat:@"do shell script \"sh -c '%@'\" with administrator privileges", command];
    NSLog(@"AppleScript commands: %@", script);
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    if ([appleScript executeAndReturnError:&errorDict]) {
        return YES;
    } else {
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : errorDict[NSAppleScriptErrorBriefMessage],
                                    NSLocalizedRecoverySuggestionErrorKey : errorDict[NSAppleScriptErrorMessage] };
        NSNumber *exitCode = errorDict[NSAppleScriptErrorNumber];

        if (error)
            *error = [NSError errorWithDomain:kLGApplicationName code:[exitCode intValue] userInfo:userInfo];
        return NO;
    }
}

- (BOOL)unmountVolume
{
    if (_mountPoint) {
        NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/hdiutil" arguments:@[ @"detach", _mountPoint ]];
        [task waitUntilExit];
        return task.terminationStatus == 0;
    }
    return YES;
}

- (BOOL)mountDMG:(NSString *)path
{
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hdiutil";
    task.arguments = @[ @"attach", path, @"-plist" ];
    task.standardOutput = [NSPipe pipe];

    [task launch];
    [task waitUntilExit];

    NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];

    if (data) {
        NSPropertyListFormat format;
        NSDictionary *dict = [NSPropertyListSerialization propertyListFromData:data
                                                              mutabilityOption:NSPropertyListImmutable
                                                                        format:&format
                                                              errorDescription:nil];

        _mountPoint = dict[@"system-entities"][1][@"mount-point"];
    }
    return task.terminationStatus == 0;
}
@end
