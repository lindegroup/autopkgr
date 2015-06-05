// LGToolsStatus.h
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

#import <Foundation/Foundation.h>

#import "LGTool.h"
#import "LGAutoPkgTool.h"
#import "LGGitTool.h"
#import "LGJSSImporterTool.h"
#import "LGMunkiTool.h"

@class LGTool;

#pragma mark Tool Status
/**
 *  Get an array of all available tools.
 */
@interface LGToolManager : NSObject

/**
 *  A block executed when when any tool's status changes.
 */
@property (copy) void (^installStatusDidChangeHandler)(LGToolManager *aManager, LGTool *changedTool);

/**
 *  Get an array of all the associated tools
 *
 *  @return Array of subclassed LGTools
 */
@property (strong, readonly) NSArray *allTools;

/**
 *  Get an array of all installed associated tools;
 *  @note if the tools +isInstalled method retruns NO, the tool will not be added to the array.
 *
 *  @return Array of installed subclassed LGTools
 */
@property (strong, readonly) NSArray *installedTools;

/**
 *  Get an array of all installed associated tools;
 *  @note if the tools +isInstalled method retruns NO, the tool will not be added to the array.
 *
 *  @return Array of installed subclassed LGTools
 */
@property (strong, readonly) NSArray *requiredTools;

/**
 *  Get an array of all installed or requried associated tools;
 *  @note if the tools +isInstalled method retruns NO, the tool will not be added to the array.
 *
 *  @return Array of installed subclassed LGTools
 */
@property (strong, readonly) NSArray *installedOrRequiredTools;

/**
 *  Get an array of all installed associated tools;
 *  @note if the tools +isInstalled method retruns NO, the tool will not be added to the array.
 *
 *  @return Array of installed subclassed LGTools
 */
@property (strong, readonly) NSArray *optionalTools;

/**
 *  Return the instance of the LGTool for a particular class.
 *
 *  @param toolClass Subclass of the LGTool to obtain an instance for.
 *
 *  @return LGTool (subclass) instance.
 */
- (id)toolOfClass:(Class)toolClass;

/**
 *  Check if required items are installed
 *
 *  @return YES if all required tools are installed.
 */
+ (BOOL)requiredItemsInstalled;

/**
 *  Display NSAlert indicating requirements
 *
 *  @param window Modal window used for the alert. Can be nil.
 */
+ (void)displayRequirementsAlertOnWindow:(NSWindow *)window;

@end
