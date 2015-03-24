//
//  LGTools.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 2/7/15.
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

extern NSString *const kLGToolAutoPkg;
extern NSString *const kLGToolGit;
extern NSString *const kLGToolJSSImporter;

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

#pragma mark Tool
/**
 *  Helper tool
 */
@interface LGTool : NSObject

// Name of the tool.
@property (copy, nonatomic, readonly) NSString *name;

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

// Mapped bool for whether tool needs installed.
@property (assign, readonly) BOOL needsInstall;

@end

#pragma mark Tool Status
/**
 *  Get populated tool objects.
 */
@interface LGToolStatus : NSObject

- (void)allToolsStatus:(void (^)(NSArray *tools))complete;

/**
 *  Get AutoPkg status
 *
 *  @param status block executed upon completion, it takes a single argument LGTool representing AutoPkg
 */
- (void)autoPkgStatus:(void (^)(LGTool *))status;

/**
 *  Get Git status
 *
 *  @param status block executed upon completion, it takes a single argument LGTool representing Git
 */
- (void)gitStatus:(void (^)(LGTool *))status;

/**
 *  Get JSSImporter status
 *
 *  @param status block executed upon completion, it takes a single argument LGTool representing JSSImporter
 */
- (void)jssImporterStatus:(void (^)(LGTool *))status;

/**
 *  Check if AutoPkg is installed.
 *
 *  @return YES if AutoPkg is installed, NO otherwise
 */
+ (BOOL)autoPkgInstalled;

/**
 *  Check if Git is installed.
 *
 *  @return YES if Git is installed, NO otherwise.
 */
+ (BOOL)gitInstalled;

/**
 *  Check if JSSImporter is installed.
 *
 *  @return YES if JSSImporter is installed, NO otherwise.
 */
+ (BOOL)jssImporterInstalled;

@end
