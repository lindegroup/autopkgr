//
//  LGInstaller.m
//  AutoPkgr
//
//  Created by Eldon on 9/9/14.
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

#import "LGInstaller.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGGitHubJSONLoader.h"
#import "LGAutoPkgrHelperConnection.h"

typedef NS_ENUM(NSInteger, LGInstallType) {
    kLGInstallerTypeUnkown = 0,
    kLGInstallerTypeDMG,
    kLGInstallerTypePKG,
};

@implementation LGInstaller {
    NSString *_mountPoint;
    NSString *_downloadURL;
}

#pragma mark - Git installer
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
    BOOL success;
    NSString *githubAPI;
    NSError *installError;

    BOOL mavericks = floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8;

    if (mavericks)
        githubAPI = kLGGitMAVReleasesJSONURL;
    else
        githubAPI = kLGGitMLReleasesJSONURL;

    success = [self runInstallerFor:@"Git" githubAPI:githubAPI error:&installError];

    if (success) {
        LGDefaults *defaults = [[LGDefaults alloc] init];

        // If the installer was successful here set the AutoPkg GIT_PATH key
        if (mavericks)
            defaults.gitPath = @"/usr/local/git/bin/git";
        else
            defaults.gitPath = @"/usr/bin/git";

        NSLog(@"Setting the Git path for AutoPkg to %@", defaults.gitPath);
    } else {
        if (installError)
            DLog(@"%@", installError);
        return [LGError errorWithCode:kLGErrorInstallGit error:error];
    }
    return success;
}

#pragma mark - AutoPkg Installer
- (BOOL)runAutoPkgInstaller:(NSError *__autoreleasing *)error
{
    NSError *installError;
    BOOL success = [self runInstallerFor:@"AutoPkg" githubAPI:kLGAutoPkgReleasesJSONURL error:&installError];
    if (!success) {
        if (installError)
            DLog(@"%@", installError);
        return [LGError errorWithCode:kLGErrorInstallAutoPkg error:error];
    }
    return success;
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

#pragma mark - JSS Addon Instller
- (BOOL)runJSSAddonInstaller:(NSError *__autoreleasing *)error
{
    NSError *installError;
    BOOL success = [self runInstallerFor:@"JSS AutoPkg Addon" githubAPI:kLGJSSAddonJSONURL error:error];
    if (!success) {
        if (installError)
            DLog(@"%@", installError);
        success = [LGError errorWithCode:kLGErrorInstallJSSAddon error:error];
    }
    return success;
}

- (void)installJSSAddon:(void (^)(NSError *))reply
{
    NSOperationQueue *bgQueue = [[NSOperationQueue alloc] init];
    [bgQueue addOperationWithBlock:^{
        NSError *error;
        [_progressDelegate startProgressWithMessage:@"Installing JSS AutoPkg Addon..."];
        [self runJSSAddonInstaller:&error];
        [_progressDelegate stopProgress:error];
        reply(error);
    }];
}

#pragma mark - Main install method
- (BOOL)runInstallerFor:(NSString *)installerName githubAPI:(NSString *)githubAPI error:(NSError *__autoreleasing *)error
{
    NSString *progressMessage;

    progressMessage = [NSString stringWithFormat:@"Downloading %@...", installerName];
    [_progressDelegate updateProgress:progressMessage progress:5.0];

    // Get the latest download URL from the GitHub API URL
    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
    _downloadURL = [loader latestReleaseDownload:githubAPI];

    // Get tmp file path for downloaded file
    NSString *tmpFileLocation = [NSTemporaryDirectory() stringByAppendingPathComponent:[_downloadURL lastPathComponent]];

    progressMessage = [NSString stringWithFormat:@"Building %@ installer package...", installerName];
    [_progressDelegate updateProgress:progressMessage progress:25.0];

    // Download to the temporary directory
    NSData *fileData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:_downloadURL]];
    if (fileData) {
        [fileData writeToFile:tmpFileLocation atomically:YES];
    } else {
        DLog(@"Could not download %@", _downloadURL);
        return NO;
    }

    NSString *pkgFile = nil;
    LGInstallType type = [self evaluateInstallerType];
    switch (type) {
    case kLGInstallerTypeUnkown:
        return NO;
        break;
    case kLGInstallerTypeDMG:
        if ([self mountDMG:tmpFileLocation] && _mountPoint) {
            // install Pkg
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_mountPoint error:nil];
            DLog(@"Contents of DMG %@ ", contents);

            // The predicate here is "CONTAINS" so we get both .pkg and .mpkg files
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"pathExtension CONTAINS[cd] 'pkg'"];
            NSString *pkg = [[contents filteredArrayUsingPredicate:predicate] firstObject];

            if (pkg) {
                DLog(@"Found installer package: %@", pkg);
                // Since this is getting invoked as an AppleScript wrapping in sh -c  you need 4 backslashes to correctly escape the whitespace
                pkgFile = [[_mountPoint stringByAppendingPathComponent:pkg] stringByReplacingOccurrencesOfString:@" " withString:@"\\\\ "];
            } else {
                DLog(@"Could not locate .pkg file.");
            }
        }
        break;
    case kLGInstallerTypePKG:
        pkgFile = tmpFileLocation;
        break;
    default:
        break;
    }

    __block BOOL success = NO;
    __block BOOL complete = NO;
    
    if (type != kLGInstallerTypeUnkown && pkgFile) {
        // Set the `installer` command
        // Install the pkg as root
        progressMessage = [NSString stringWithFormat:@"Installing %@...", installerName];
        
        [_progressDelegate updateProgress:progressMessage progress:75.0];
        
        NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
        assert(authorization != nil);

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
            [helper connectToHelper];
            [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
                DLog(@"%@",error);
                success = NO;
                complete = YES;
            }] installPackageFromPath:pkgFile authorization:authorization reply:^(NSError *error) {
                success = error ? NO:YES;
                complete = YES;
            }];
        }];
        
        while (!complete) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
        }
        
        progressMessage = [NSString stringWithFormat:@"%@ installation complete.", installerName];
        
        [_progressDelegate updateProgress:progressMessage progress:100.0];

        if (type == kLGInstallerTypeDMG) {
            progressMessage = [NSString stringWithFormat:@"Unmounting %@ disk image...", installerName];
            [_progressDelegate updateProgress:progressMessage progress:100.0];
            [self unmountVolume];
        }
    }
    return success;
}

#pragma mark - Util Methods
- (LGInstallType)evaluateInstallerType
{
    LGInstallType type = kLGInstallerTypeUnkown;

    NSPredicate *dmgPredicate = [NSPredicate predicateWithFormat:@"pathExtension CONTAINS[cd] 'dmg'"];
    NSPredicate *pkgPredicate = [NSPredicate predicateWithFormat:@"pathExtension CONTAINS[cd] 'pkg'"];

    if ([pkgPredicate evaluateWithObject:_downloadURL]) {
        type = kLGInstallerTypePKG;
    } else if ([dmgPredicate evaluateWithObject:_downloadURL]) {
        type = kLGInstallerTypeDMG;
    }

    return type;
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

        if (errorStr) {
            DLog(@"Error creating plist %@", errorStr);
        } else {
            DLog(@"hdiutil output dictionary: %@", dict);
        }

        for (NSDictionary *d in dict[@"system-entities"]) {
            NSString *mountPoint = d[@"mount-point"];
            if (mountPoint) {
                _mountPoint = mountPoint;
                break;
            }
        }

        NSLog(@"Mounting installer DMG to %@", _mountPoint);

    } else {
        DLog(@"There was a problem retrieving the standard output of the hdiutil process");
    }

    return task.terminationStatus == 0;
}
@end
