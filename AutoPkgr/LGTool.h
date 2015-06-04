//
//  LGTools.h
//  AutoPkgr
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
//

#import <Foundation/Foundation.h>
#import "LGProgressDelegate.h"

extern NSString *const kLGNotificationToolStatusDidChange;

typedef NS_ENUM(NSInteger, LGToolTypeFlags) {
    /**
     *  Unknown Tool Type.
     */
    kLGToolTypeUnspecified = 0,

    /**
     *  Add this as a flag if the tool is a shared processor.
     *  If this is specified make sure to include the default
     *  repo property in the subclass.
     */
    kLGToolTypeAutoPkgSharedProcessor = 1 << 0,

    /**
     *  Flag to declare the tool requires a package installation.
     */
    kLGToolTypeInstalledPackage = 1 << 1,

    /**
     *  Flag to declare that it is acceptable to uninstall the tool.
     *  @note this is only used when the kLGToolTypeInstalledPackage is also set
     */
    kLGToolTypeUninstallableTool = 1 << 2,
};

/**
 *  Tool install status
 */
typedef NS_ENUM(OSStatus, LGToolInstallStatus) {
    /**
     *  Tool is not installed.
     */
    kLGToolNotInstalled,
    /**
     *  Tool is installed, but an update is available for the tool.
     */
    kLGToolUpdateAvailable,
    /**
     *  Tool is installed.
     */
    kLGToolUpToDate,
};

#pragma mark - Tool
@class LGToolInfo;

/**
 *  LGTool is an abstract class for associated tools.
 *  @note The LGTool class needs to be be subclassed. You will also need to import the LGTool+Protocols.h file into your subclass.
 *  @discussion A good example of how to use an instance of this tool is
    @code
 LGToolSubclass *tool = [[LGToolSubclass alloc] init];
 tool.progressDelegate = _progressDelegate;
 someButton.target = tool;
 someButton.target.action = @selector(install:);

 [tool getInfo:^(LGToolInfo *info) {
    someButton.target.enabled = info.needsInstalled;
    someButton.target.title = info.installButtonTitle;
    someStatusImage.image = info.statusImage;
    someTextFiled.stringValue = info.statusString;
 }];
    @endcode
 *  @discussion There a a number of properties / methods that a subclass is required to override @code
 // These are required by all.
 + (NSString *)name

 // These are only required for installer package flag set.
 + (NSString *)binary
 + (NSArray *)components
 + (NSString *)gitHubURL
 + (NSString *)packageIdentifier

 @endcode Many other methods may need to get overridden for proper functioning. See LGTool.h and LGTool+Private.h for a comprehensive list.
 */

@interface LGTool : NSObject
/**
 *  Name of the Tool
 */
+ (NSString *)name;

/**
 * Check if the tool meets system requirements to proceed with installation.
 *
 *  @param error Populated error object if requirements are not met.
 *
 *  @return YES if requirements are met, no otherwise.
 */
+ (BOOL)meetsRequirements:(NSError **)error;

// If the tool is installed.
+ (BOOL)isInstalled;


@property (weak) id<LGProgressDelegate> progressDelegate;

#pragma mark - Implemented in the Abstract class
@property (copy, nonatomic, readonly) NSString *name;
@property (assign, nonatomic, readonly) BOOL *isInstalled;

// LGToolInfo object with local and remote status information and useful UI mappings.
@property (copy, nonatomic, readonly) LGToolInfo *info;

@property (copy) void (^infoUpdateHandler)(LGToolInfo *info);

- (void)getInfo:(void (^)(LGToolInfo *info))reply;

// update the tool.info property and if infoUpdateHandler has been set execute the completion block.
- (void)refresh;

/**
 *  Run the installer asynchronously
 *
 *  @param progress block invoked when progress information is available.
 *  @param reply block invoked upon completion.
 */
- (void)install:(void (^)(NSString *message, double progress))progress reply:(void (^)(NSError *error))reply;

/**
 *  Install the tool
 *
 *  @param sender UI Object. This can be set as a button's action.
 *  @note To progress updates are sent to the progressDelegate property
 *  @discussion Upon successful completion, if an object is sent as sender and that object responds @code @selector(action) @endcode the action will get reset to `uninstall`
 */
- (void)install:(id)sender;

/**
 *  Uninstall the tool
 *
 *  @param progress block invoked when progress information is available.
 *  @param reply block invoked upon completion.
 */
- (void)uninstall:(void (^)(NSString *message, double progress))progress reply:(void (^)(NSError *error))reply;

/**
 *  Uninstall the tool
 *
 *  @param sender UI object. This can be set as a button's action.
 *  @note When this method is called, progress updates are sent to the progressDelegate property.
 *  @note You can also assign a button's `target` and `action` to the LGTool will invoke this action
 *  @discussion Upon successful completion, if an object is sent as sender and that object responds @code @selector(action)  @endcode the action will get reset to `install`
 */
- (void)uninstall:(id)sender;

@end

#pragma mark Tool Info Object
/**
 *  LGTool information with useful mapped values.
 */
@interface LGToolInfo : NSObject

// Installed version.
@property (copy, nonatomic, readonly) NSString *installedVersion;

// Version available on GitHub.
@property (copy, nonatomic, readonly) NSString *remoteVersion;

// Status of the item.
@property (assign, nonatomic, readonly) LGToolInstallStatus status;

#pragma mark - Tool Mappings
// Mapped image of the small green/yellow/red globe.
@property (copy, nonatomic, readonly) NSImage *statusImage;

// Mapped string for installed/update available/not installed.
@property (copy, nonatomic, readonly) NSString *statusString;

// Mapped title for an install button.
@property (copy, nonatomic, readonly) NSString *installButtonTitle;

// Mapped bool for whether the button should be enabled.
@property (assign, readonly) BOOL installButtonEnabled;

// Mapped bool for whether tool needs installed or updated.
@property (assign, readonly) BOOL needsInstalled;

// Selector to specify install / uninstall behavior.
@property (assign, readonly) SEL targetAction;

@end
