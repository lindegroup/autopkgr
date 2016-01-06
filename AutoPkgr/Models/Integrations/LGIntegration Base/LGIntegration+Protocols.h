//
//  LGIntegration+Protocols.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGIntegration.h"
#import "LGGitHubJSONLoader.h"

/* Integration protocols are used as a base line to determine how the integration is insatlled and configured.
 * you should conform to as many as necissary to correctly describe the integration.
 */

#pragma mark - Protocols
#pragma mark - General integration protocol
@class LGGitHubReleaseInfo;



#pragma mark - Package Installer Protocol
/**
 *  If the integration uses an installer package conform to this protocol.
 */
@protocol LGIntegrationPackageInstaller <LGIntegrationSubclass>
@required
/**
 *  Path to the main executable file for the integration
 *  @note this is checked for executable status
 */
+ (NSString *)binary;

/**
 *  The GitHub API address for the repo release. This is typically similar to this https://api.github.com/repos/myrepo/releases
 */
+ (NSString *)gitHubURL;

/**
 *  The package identifier for the integration. Primarily used to determine items during uninstall:
 */
+ (NSArray *)packageIdentifiers;


@optional
/**
 *  Whether the integration is uninstallable. Defaults to YES;
 *
 *  @return YES if the integration can be uninstalled, no otherwise
 */
+ (BOOL)isUninstallable;

/**
 *  An optionally dedicated download URL location. By default this is the browser_download_url of the first asset of the first array retrieved from the gitHubURL
 */
@property (copy, nonatomic, readonly) NSString *downloadURL;

@end

#pragma mark - Shared Processor Protocol
/**
 *  If the integration is a shared processor conform to this protocol.
 */
@protocol LGIntegrationSharedProcessor <LGIntegrationSubclass>
@required
/**
 *  Default repository if the integration is an autopkg shared processor.
 */
+ (NSString *)defaultRepository;

/**
 *  Key cooresponding to the report plist's "xxx_summary_results"
 *
 *  @return full key for the integration's summary results.
 */
+ (NSString *)summaryResultKey;
@end



@interface LGIntegration () <LGProgressDelegate>
-(NSString *)remoteVersion; // This is just here to so subclasses have access to the super's implementation.

#pragma mark - Instance methods to override

/**
 *  GitHubInfo object
 */
@property (strong, nonatomic) LGGitHubReleaseInfo *gitHubInfo;

/**
 *  Get a version string via NSTask
 *
 *  @param exec      executable path to access the version
 *  @param arguments arguments passed to the executable
 *
 *  @return raw output from the task.
    @note All post processing of string such as stripping newlines/whitespace must be handled separately.
 */

- (NSString *)versionTaskWithExec:(NSString *)exec arguments:(NSArray *)arguments;

/**
 *  Populate an error object for failed requirements
 *
 *  @param reason the localizedSuggestion for the error
 *
 *  @return Populated NSError object
 */
+ (NSError *)requirementsError:(NSString *)reason;

@end
