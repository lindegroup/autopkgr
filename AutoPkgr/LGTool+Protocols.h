//
//  LGTool_LGTool+Protocols.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGTool.h"
#import "LGGitHubJSONLoader.h"

/* Tool protocols are used as a base line to determine how the tool is insatlled and configured.
 * you should conform to as many as necissary to correctly describe the tool.
 */

#pragma mark - Protocols
#pragma mark - General Tool Protocol
@class LGGitHubReleaseInfo;

/* Tool subclasses automatically conform to this protocol,
 * so it is unnecissary to explicitly declare it */
@protocol LGToolSubclass <NSObject>
@required
/**
 *  Name of the Tool
 */
+ (NSString *)name;

/**
 *  Any custom install actions that need to be taken.
 */
- (void)customInstallActions;

/**
 *  Any custom uninstall actions that need to be taken.
 */

- (void)customUninstallActions;

@optional
/**
 *  By default this looks for the version in the receipt for an installed package with the name specified in packageIdentifier. Override this to customize the technique.
 *  @note you should not call this directly externally, and is used to initialize LGToolInfo objects without the need for subclassing that too. To access this information externally use the tool.info property.
 */
@property (copy, nonatomic, readonly) NSString *installedVersion;

/**
 *  By default this is obtained from the GitHub repo. Override this to provide alternate ways to determine remote version.
 *  @note you should not call this directly, and is used to initialize LGToolInfo objects without the need for subclassing that too. To access this information externally use the tool.info property.
 */
@property (copy, nonatomic, readonly) NSString *remoteVersion;

@end

#pragma mark - Package Installer Protocol
/**
 *  If the tool uses an installer package conform to this protocol.
 */
@protocol LGToolPackageInstaller <NSObject>
@required
/**
 *  Path to the main executable file for the tool
 *  @note this is checked for executable status
 */
+ (NSString *)binary;

/**
 *  The GitHub API address for the repo release. This is typically similar to this https://api.github.com/repos/myrepo/releases
 */
+ (NSString *)gitHubURL;

/**
 *  The package identifier for the tool. Primarily used to determine items during uninstall:
 */
+ (NSArray *)packageIdentifiers;

@optional
/**
 *  Whether the tool is uninstallable. Defaults to YES;
 *
 *  @return YES if the tool can be uninstalled, no otherwise
 */
+ (BOOL)isUninstallable;

/**
 *  An optionally dedicated download URL location. By default this is the browser_download_url of the first asset of the first array retrieved from the gitHubURL
 */
@property (copy, nonatomic, readonly) NSString *downloadURL;

@end

#pragma mark - Shared Processor Protocol
/**
 *  If the tool is a shared processor conform to this protocol.
 */
@protocol LGToolSharedProcessor <LGToolSubclass>
@required
/**
 *  Components of the tool that indicate the tool is successful installed.
 *  @note This is only required when the tool has the SharedProcessor flag set.
 *  @note it is unnecessary to list every item of the installer. If you have a tool that installs components in separate file system locations you should list one from each. For example JSSImporter.py exists in /Library/AutoPkg/autopkglib, but requires the python-jss library in /Library/Python/2.7/site-packages/python_jss-0.5.9-py2.7.egg/jss so each should be checked to determine if successfully installed
 */
+ (NSArray *)components;

/**
 *  Default repository if the tool is an autopkg shared processor.
 */
+ (NSString *)defaultRepository;

@end

@interface LGTool () <LGToolSubclass, LGProgressDelegate>

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
- (NSError *)requirementsError:(NSString *)reason;
@end
