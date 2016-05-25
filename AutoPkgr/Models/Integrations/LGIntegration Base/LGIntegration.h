//
//  LGIntegration.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
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

#import <Foundation/Foundation.h>
#import "LGProgressDelegate.h"

@class LGIntegrationInfo;

extern NSString *const kLGNotificationIntegrationStatusDidChange;

typedef NS_ENUM(NSInteger, LGIntegrationTypeFlags) {
    /**
     *  Unknown Integration Type.
     */
    kLGIntegrationTypeUnspecified = 0,

    /**
     *  Add this as a flag if the integration is a shared processor.
     *  If this is specified make sure to include the default
     *  repo property in the subclass.
     */
    kLGIntegrationTypeAutoPkgSharedProcessor = 1 << 0,

    /**
     *  Flag to declare the integration requires a package installation.
     */
    kLGIntegrationTypeInstalledPackage = 1 << 1,

    /**
     *  Flag to declare that it is acceptable to uninstall the integration.
     *  @note this is only used when the kLGIntegrationTypeInstalledPackage is also set
     */
    kLGIntegrationTypeUninstallableIntegration = 1 << 2,
};

/**
 *  Integration install status
 */
typedef NS_ENUM(OSStatus, LGIntegrationInstallStatus) {
    /**
     *  Integration is not installed.
     */
    kLGIntegrationNotInstalled,
    /**
     *  Integration is installed, but an update is available for the integration.
     */
    kLGIntegrationUpdateAvailable,
    /**
     *  Integration is installed.
     */
    kLGIntegrationUpToDate,
};

#pragma mark - Integration Protocol
/**
 *  Base protocol for the subclass. This should not be used as a protocol directly,
 *  instead Import any of the sub-protocols listed in LGIntegration+Protocols.
 */
@protocol LGIntegrationSubclass <NSObject>
@required
/**
 *  Name of the integration
 */
+ (NSString *)name;

/**
 *  @return  Author / License
 */
+ (NSString *)credits;

/**
 *  @return Link to the home page of the integration.
 */
+ (NSURL *)homePage;

@optional
/**
 *  Short Name of the Integration if the name too long to fit on a button
 */
+ (NSString *)shortName;

/**
 *  Components of the integration that indicate the integration is successful installed.
 *  @note it is unnecessary to list every item of the installer. If you have a integration that installs components in separate file system locations you should list one from each. For example JSSImporter.py exists in /Library/AutoPkg/autopkglib, but requires the python-jss library in /Library/Python/2.7/site-packages/python_jss-0.5.9-py2.7.egg/jss so each should be checked to determine if successfully installed
 */
+ (NSArray *)components;

/**
 *  Can the integration can be uninstalled.
 */
+ (BOOL)isUninstallable;

/**
 *  Any custom install actions that need to be taken.
 */
- (void)customInstallActions:(void(^)(NSError *error))reply;

/**
 *  Any custom uninstall actions that need to be taken.
 */
- (void)customUninstallActions:(void(^)(NSError *error))reply;

/**
 *  By default this looks for the version in the receipt for an installed package with the name specified in packageIdentifier. Override this to customize the technique.
 *  @note you should not call this directly externally, and is used to initialize LGIntegrationInfo objects without the need for subclassing that too. To access this information externally use the integration.info property.
 */
@property (copy, nonatomic, readonly) NSString *installedVersion;

/**
 *  By default this is obtained from the GitHub repo. Override this to provide alternate ways to determine remote version.
 *  @note you should not call this directly, and is used to initialize LGIntegrationInfo objects without the need for subclassing that too. To access this information externally use the integration.info property.
 */
@property (copy, nonatomic, readonly) NSString *remoteVersion;

@end

/**
 *  LGIntegration is an abstract class for associated integrations.
 *  @note The LGIntegration class needs to be be subclassed. You will also need to import the LGIntegration+Protocols.h file into your subclass.
 *  @discussion A good example of how to use an instance of this integration is
    @code
 LGIntegrationSubclass *integration = [[LGIntegrationSubclass alloc] init];
 integration.progressDelegate = _progressDelegate;
 someButton.target = integration;
 someButton.target.action = @selector(install:);

 // getInfo will automatically trigger an
 // asynchronous request for remote information.
 [integration getInfo:^(LGIntegrationInfo *info) {
    someButton.target.enabled = info.needsInstalled;
    someButton.target.title = info.installButtonTitle;
    someStatusImage.image = info.statusImage;
    someTextFiled.stringValue = info.statusString;
 }];
    @endcode
 *  @discussion A subclass should conform to at least one of the Integration protocols Many other methods may need to get overridden for proper functioning. See LGIntegration.h and LGIntegration+Private.h for a comprehensive list.
 */
@interface LGIntegration : NSObject

/**
 * Check if the integration meets system requirements to proceed with installation.
 *
 *  @param error Populated error object if requirements are not met.
 *
 *  @return YES if requirements are met, no otherwise.
 */
+ (BOOL)meetsRequirements:(NSError **)error;

// If the integration is installed.
+ (BOOL)isInstalled;

@property (weak) id<LGProgressDelegate> progressDelegate;

#pragma mark - Implemented in the Abstract class
@property (copy, nonatomic, readonly) NSString *name;

@property (assign, nonatomic, readonly) BOOL isInstalled;
@property (assign, nonatomic, readonly) BOOL isRefreshing;

// LGIntegrationInfo object with local and remote status information and useful UI mappings.
@property (strong, nonatomic, readonly) LGIntegrationInfo *info;

/**
 *  Block that is executed when the status of the integration changes. It's triggered during `-install:, -uninstall: -refresh`. The block has no return value and takes one parameter, LGIntegrationInfo, an object with mapped values for use with IBOutlets
 */
@property (copy) void (^infoUpdateHandler)(LGIntegrationInfo *info);

/**
 *  Asynchronous retrevial of mapped values for use with IBOutlets.
 *
 *  @param reply Reply block has no return value and takes one parameter, LGIntegrationInfo, an object with mapped values for use with IBOutlets
 */
- (void)getInfo:(void (^)(LGIntegrationInfo *info))reply;

// update the integration.info property and if infoUpdateHandler has been set execute the completion block.
- (void)refresh;

/**
 *  Run the installer asynchronously
 *
 *  @param progress block invoked when progress information is available.
 *  @param reply block invoked upon completion.
 */
- (void)install:(void (^)(NSString *message, double progress))progress reply:(void (^)(NSError *error))reply;

/**
 *  Install the integration
 *
 *  @param sender UI Object. This can be set as a button's action.
 *  @note To progress updates are sent to the progressDelegate property
 *  @discussion Upon successful completion, if an object is sent as sender and that object responds @code @selector(action) @endcode the action will get reset to `uninstall`
 */
- (void)install:(id)sender;

/**
 *  Uninstall the integration
 *
 *  @param progress block invoked when progress information is available.
 *  @param reply block invoked upon completion.
 */
- (void)uninstall:(void (^)(NSString *message, double progress))progress reply:(void (^)(NSError *error))reply;

/**
 *  Uninstall the integration
 *
 *  @param sender UI object. This can be set as a button's action.
 *  @note When this method is called, progress updates are sent to the progressDelegate property.
 *  @note You can also assign a button's `target` and `action` to the LGIntegration will invoke this action
 *  @discussion Upon successful completion, if an object is sent as sender and that object responds @code @selector(action)  @endcode the action will get reset to `install`
 */
- (void)uninstall:(id)sender;

@end

#pragma mark Integration Info Object
/**
 *  LGIntegration information with useful mapped values.
 */
@interface LGIntegrationInfo : NSObject

// Installed version.
@property (copy, nonatomic, readonly) NSString *installedVersion;

// Version available on GitHub.
@property (copy, nonatomic, readonly) NSString *remoteVersion;

// Status of the item.
@property (assign, nonatomic, readonly) LGIntegrationInstallStatus status;

// Mapped bool for whether integration needs installed or updated.
@property (assign, readonly) BOOL needsInstalled;

#pragma mark - Integration Mappings
// Mapped image of the small green/yellow/red globe.
@property (copy, nonatomic, readonly) NSImage *statusImage;

// Mapped string for installed/update available/not installed.
@property (copy, nonatomic, readonly) NSString *statusString;

// Mapped title for an install button.
@property (copy, nonatomic, readonly) NSString *installButtonTitle;

// Mapped bool for whether the button should be enabled.
@property (assign, readonly) BOOL installButtonEnabled;

// Selector to specify install / uninstall behavior.
@property (assign, readonly) SEL installButtonTargetAction;

// Mapped title for an install button.
@property (copy, nonatomic, readonly) NSString *configureButtonTitle;

// Selector to specify install / uninstall behavior.
@property (assign, readonly) SEL configureButtonTargetAction;

@end
