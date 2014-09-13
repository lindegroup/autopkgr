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

    
    LGGitHubJSONLoader *jsonLoader = [[LGGitHubJSONLoader alloc] init];
    NSString *downloadURL = [jsonLoader getGitDownloadURL];
    
    NSString *tmpFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[downloadURL lastPathComponent]];
    DLog(@"Setting download location to: %@",tmpFile);
    
    // Download Git to the temporary directory
    if (![[NSFileManager defaultManager] fileExistsAtPath:tmpFile]) {
        [_progressDelegate updateProgress:@"Downloading Git..." progress:5.0];
        NSData *gitDMG = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:downloadURL]];
        
        [_progressDelegate updateProgress:@"Building Git installer package..." progress:25.0];
        if (!gitDMG || ![gitDMG writeToFile:tmpFile atomically:YES]) {
            NSLog(@"Could not write the Git installer disk iamge to the system path.");
            return [LGError errorWithCode:kLGErrorInstallGit error:error];
        }
    }

    // Open DMG
    BOOL RC = NO;
    [_progressDelegate updateProgress:@"Mounting Git disk image..." progress:50.0];
    if ([self mountDMG:tmpFile] && _mountPoint) {
        // install Pkg
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_mountPoint error:nil];
        DLog(@"Contents of DMG %@ ",contents);
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension CONTAINS[cd] 'pkg'"];

        NSString *pkg = [[contents filteredArrayUsingPredicate:predicate] firstObject];
        if ( pkg ) {
            DLog(@"Using .pkg %@",pkg);
        } else {
            DLog(@"Could not locate .pkg file.");
        }
        // Since this is getting invoked as an apple script wrapping in sh -c  you need 4 forward slashes to correctly escape the whitespace
        NSString *appleScriptEscapedPath = [[_mountPoint stringByAppendingPathComponent:pkg] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
        
        NSString *installCommand = [NSString stringWithFormat:@"/usr/sbin/installer -pkg %@ -target /", appleScriptEscapedPath];
        DLog(@"Running package install command: %@", installCommand);
        [_progressDelegate updateProgress:@"Installing Git..." progress:75.0];
        
        RC = [self runCommandAsRoot:installCommand error:error];
    }
    
    LGDefaults *defaults = [[LGDefaults alloc] init];
    
    if (RC) {
        // If the installer was successful here set the autopkg GIT_PATH key
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8) {
            // Mavericks and beyond
            defaults.gitPath = @"/usr/local/git/bin/git";
        } else {
            // Mountian Lion compatible
            defaults.gitPath = @"/usr/bin/git";
        }
        DLog(@"Setting the Git path for AutoPkg to %@",defaults.gitPath);
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
        NSString *errorStr;
        NSPropertyListFormat format;
        NSDictionary *dict = [NSPropertyListSerialization propertyListFromData:data
                                                              mutabilityOption:NSPropertyListImmutable
                                                                        format:&format
                                                              errorDescription:&errorStr];
        
        if(errorStr) {
            DLog(@"Error creating plist %@",errorStr);
        } else {
            DLog(@"hdituil output dictionary %@",dict);
        }
        
        for ( NSDictionary *d in dict[@"system-entities"]){
            NSString *mountPoint = d[@"mount-point"];
            if (mountPoint) {
                _mountPoint = mountPoint;
                break;
            }
        }

        NSLog(@"Mounting installer DMG to %@",_mountPoint);

    } else {
        DLog(@"There was a problem with the stdout of the hdituil process");
    }
    
    return task.terminationStatus == 0;
}
@end
