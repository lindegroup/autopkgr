// LGGitIntegration.m
//
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

#import "LGGitIntegration.h"
#import "LGIntegration+Protocols.h"
#import "LGDefaults.h"

#import "NSData+taskData.h"

#import <AHProxySettings/NSTask+useSystemProxies.h>

static NSString *const kLGOfficialGit = @"/usr/local/git/bin/git";
static NSString *const kLGCLIToolsGit = @"/Library/Developer/CommandLineTools/usr/bin/git";
static NSString *const kLGXcodeGit = @"/Applications/Xcode.app/Contents/Developer/usr/bin/git";
static NSString *const kLGHomeBrewGit = @"/usr/local/bin/git";
static NSString *const kLGBoxenBrewGit = @"/opt/boxen/homebrew/bin/git";

@interface LGGitIntegration ()<LGIntegrationPackageInstaller>
@end

static NSArray *knownGitPaths()
{
    return @[ kLGOfficialGit,
              kLGBoxenBrewGit,
              kLGHomeBrewGit,
              kLGXcodeGit,
              kLGCLIToolsGit,
    ];
}

@implementation LGGitIntegration

@synthesize installedVersion = _installedVersion;
@synthesize remoteVersion = _remoteVersion;
@synthesize downloadURL = _downloadURL;
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"Git";
}

+ (NSString *)credits {
    return @"The GNU General Public License (GPL-2.0)";
}

+ (NSURL *)homePage {
    return [NSURL URLWithString:@"https://git-scm.com"];
}

+ (NSArray *)components
{
    return @[[self binary],
              ];
}

+ (NSString *)binary
{
    NSString *binary = nil;

    NSFileManager *fm = [[NSFileManager alloc] init];
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    // First see if AutoPkg already has a GIT_PATH key set,
    // and if the executable still exists.
    BOOL isDir;
    NSString *currentGit = [defaults gitPath];

    if ([fm fileExistsAtPath:currentGit isDirectory:&isDir] && !isDir) {
        if ([fm isExecutableFileAtPath:currentGit]) {
            binary = currentGit;
        }
    } else {
        // If nothing is set, then iterate through the list
        // of known git paths trying to locate one.
        for (NSString *path in knownGitPaths()) {
            NSString *gitExec = path;
            if ([fm isExecutableFileAtPath:gitExec]) {
                // if we found a viable git binary write it into AutoPkg's preferences
                binary = gitExec;
            }
        }
    }
    defaults.gitPath = binary;
    return binary;
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/timcharper/git_osx_installer/releases";
}

+ (NSArray *)packageIdentifiers
{
    if ([[[LGDefaults standardUserDefaults] gitPath] isEqualToString:kLGOfficialGit]) {
        return @[@"GitOSX.Installer.git221Universal.git.pkg"];
    }
    return nil;
}

+ (BOOL)isUninstallable {
    return NO;
}

#pragma mark - Instance overrides.
- (void)customInstallActions:(void (^)(NSError *))reply
{
    [[LGDefaults standardUserDefaults] setGitPath:kLGOfficialGit];
    reply(nil);
}

- (NSString *)installedVersion
{
    NSString *rawVersion = [self versionTaskWithExec:[[self class] binary]
                                           arguments:@[ @"--version" ]];

    NSString *cleanVersion = [[rawVersion stringByReplacingOccurrencesOfString:@"git version " withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    _installedVersion = [[cleanVersion componentsSeparatedByString:@" "] firstObject];

    return _installedVersion;
}

- (NSString *)remoteVersion
{
    // Only return a remote version if currently using the official Git.
    if (!_remoteVersion && [[[self class] binary] isEqualToString:kLGOfficialGit]) {
        _remoteVersion = [super remoteVersion];
    }
    return _remoteVersion;
}

- (NSString *)downloadURL
{
    if (!_downloadURL) {
        BOOL OVER_10_8 = floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_8;

        NSPredicate *match = [NSPredicate predicateWithFormat:@"SELF ENDSWITH[CD] %@",
                                                              OVER_10_8 ? @"-mavericks.dmg" : @"-snow-leopard.dmg"];

        _downloadURL = [[self.gitHubInfo.latestReleaseDownloads filteredArrayUsingPredicate:match] firstObject];
#if DEBUG
        NSLog(@"Using download url for %@: %@", [[self class] name], _downloadURL);
#endif
    }
    return _downloadURL;
}

#pragma mark - Integration Extensions
+(BOOL)officialGitInstalled
{
    return [[NSFileManager defaultManager] isExecutableFileAtPath:kLGOfficialGit];
}

+ (void)gitTaskWithArguments:(NSArray *)args repoPath:(NSString *)repoPath reply:(void (^)(NSString *, NSError *))reply {


    // Dispatch queue for writing data.
    dispatch_queue_t git_data_queue = dispatch_queue_create("com.lindegroup.git.data.queue", DISPATCH_QUEUE_SERIAL );

    // Dispatch quque to send the reply back on.
    dispatch_queue_t git_callback_queue = dispatch_get_current_queue();

    NSString *binary = [self binary];
    if (binary == nil) {
        reply(nil, [self gitErrorWithMessage:@"Could not locate the git binary." code:kLGGitErrorNotInstalled]);
    }

    __block NSMutableData *outData = [[NSMutableData alloc] init];
    __block NSMutableData *errData = [[NSMutableData alloc] init];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = binary;
    task.arguments = args;
    
    if (access(repoPath.UTF8String,F_OK) == 0) {
        task.currentDirectoryPath = repoPath;
    }

    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    [task useSystemProxiesForDestination:@"github.com"];

    NSFileHandle *outHandle = [task.standardOutput fileHandleForReading];
    [outHandle setReadabilityHandler:^(NSFileHandle *fh) {
        /* We append mutable data here in order to protect against the
         * pipe's buffer from getting filled up causing task to hang. */
        dispatch_sync(git_data_queue, ^{
            [outData appendData:fh.availableData];
        });
    }];

    NSFileHandle *errHandle = [task.standardError fileHandleForReading];
    [errHandle setReadabilityHandler:^(NSFileHandle *fh) {
        dispatch_sync(git_data_queue, ^{
            [errData appendData:fh.availableData];
        });
    }];

    task.terminationHandler = ^(NSTask *aTask){
        dispatch_sync(git_data_queue, ^{
            NSString *stdOut = nil;

            // nil out the readability handlers.
            outHandle.readabilityHandler = nil;
            errHandle.readabilityHandler = nil;

            // Get any remaining data from the handle.
            [outData appendData:[outHandle readDataToEndOfFile]];
            [errData appendData:[errHandle readDataToEndOfFile]];

            if(outData.length){
                stdOut = outData.taskData_string;
            }

             NSError *error = [self gitErrorWithMessage:errData.taskData_string code:aTask.terminationStatus];

            dispatch_async(git_callback_queue, ^{
                reply(stdOut, error);
            });
        });
    };
    [task launch];
}

+ (NSError *)gitErrorWithMessage:(NSString *)message code:(NSInteger)code {
    NSError *error = nil;
    if (code != 0) {
        error = [NSError errorWithDomain:@"AutoPkgr Git"
                                    code:code
                                userInfo:@{NSLocalizedDescriptionKey:@"There was a problem executing git.",
                                           NSLocalizedRecoverySuggestionErrorKey:message ?: @""}];
    }
    return error;
}


@end
