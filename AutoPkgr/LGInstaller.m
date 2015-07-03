//
//  LGInstaller.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 9/9/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGInstaller.h"
#import "LGAutoPkgr.h"
#import "LGHostInfo.h"
#import "LGGitHubJSONLoader.h"
#import "LGAutoPkgrHelperConnection.h"

#import <AFNetworking/AFNetworking.h>

typedef NS_ENUM(NSInteger, LGInstallType) {
    kLGInstallerTypeUnknown = 0,
    kLGInstallerTypeDMG,
    kLGInstallerTypePKG,
};

@implementation LGInstaller {
    NSString *_mountPoint;
}

#pragma mark - Main install methods
- (void)runInstallerFor:(NSString *)installerName
              githubAPI:(NSString *)githubAPI
                  reply:(void (^)(NSError *error))reply
{
    __block NSString *progressMessage;

    if (!_downloadURL && githubAPI) {
        progressMessage = [NSString stringWithFormat:@"Getting latest release info from GitHub..."];
        [_progressDelegate updateProgress:progressMessage progress:5.0];

        // Get the latest download URL from the GitHub API URL
        LGGitHubReleaseInfo *info = [[LGGitHubReleaseInfo alloc] initWithURL:githubAPI];
        _downloadURL = info.latestReleaseDownload;
    }

    [self runInstaller:installerName reply:reply];
}

- (void)runInstaller:(NSString *)installerName
               reply:(void (^)(NSError *error))reply
{
    NSAssert([_progressDelegate conformsToProtocol:@protocol(LGProgressDelegate)], @"An approperiate progress delegate is not set for installer");

    __block NSString *progressMessage;

    // Get tmp file path for downloaded file
    NSString *tmpFileLocation = [NSTemporaryDirectory() stringByAppendingPathComponent:[_downloadURL lastPathComponent]];

    progressMessage = [NSString stringWithFormat:@"Downloading %@ installer...", installerName];
    [_progressDelegate updateProgress:progressMessage progress:25.0];

    // Download to the temporary directory
    // Create the NSURLRequest object with the given URL
    NSURL *url = [NSURL URLWithString:_downloadURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                         timeoutInterval:15.0];

    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];

    operation.outputStream = [NSOutputStream outputStreamToFileAtPath:tmpFileLocation append:NO];

    [operation.outputStream open];

    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        double progress  = ((double)totalBytesRead / (double)totalBytesExpectedToRead) * 100;

        NSString *message = [NSString stringWithFormat:@"Downloading %@: %.02f/%.02f MB",
                             installerName,
                             (float)totalBytesRead/1024/1024,
                             (float)totalBytesExpectedToRead/1024/1024];

        [_progressDelegate updateProgress:message progress:progress];
    }];

    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *pkgFile = nil;

        LGInstallType type = [self evaluateInstallerType];
        switch (type) {
            case kLGInstallerTypeUnknown:
                reply([LGError errorWithCode:kLGErrorInstallingGeneric]);
                return ;
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
                        pkgFile = [_mountPoint stringByAppendingPathComponent:pkg];
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

        if (type != kLGInstallerTypeUnknown && pkgFile) {
            // Set the `installer` command
            // Install the pkg as root
            progressMessage = [NSString stringWithFormat:@"Running %@ installer...", installerName];

            [_progressDelegate updateProgress:progressMessage progress:75.0];

            NSData *authorization = [LGAutoPkgrAuthorizer authorizeHelper];
            assert(authorization != nil);

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
                [helper connectToHelper];


                helper.connection.exportedObject = _progressDelegate;
                helper.connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LGProgressDelegate)];


                [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
                    DLog(@"%@",error);
                    reply(error);
                }] installPackageFromPath:pkgFile authorization:authorization reply:^(NSError *error) {
                    progressMessage = [NSString stringWithFormat:@"%@ installation complete.", installerName];

                    [_progressDelegate updateProgress:progressMessage progress:100.0];

                    if (type == kLGInstallerTypeDMG) {
                        progressMessage = [NSString stringWithFormat:@"Unmounting %@ disk image...", installerName];
                        [_progressDelegate updateProgress:progressMessage progress:100.0];
                        [self unmountVolume];
                    }
                    reply(error);
                }];
            }];
        } else {
            reply([LGError errorWithCode:kLGErrorInstallingGeneric]);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        reply(error);
    }];

    [operation start];
}

#pragma mark - Util Methods
- (LGInstallType)evaluateInstallerType
{
    LGInstallType type = kLGInstallerTypeUnknown;

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
    if (_mountPoint.length) {
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
