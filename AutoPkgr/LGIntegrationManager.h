// LGIntegrationsStatus.h
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

#import "LGIntegration.h"
#import "LGAutoPkgIntegration.h"
#import "LGGitIntegration.h"
#import "LGJSSImporterIntegration.h"
#import "LGMunkiIntegration.h"
#import "LGAbsoluteManageIntegration.h"
#import "LGMacPatchIntegration.h"

@class LGIntegration;

#pragma mark Integration Status
/**
 *  Get an array of all available integrations.
 */
@interface LGIntegrationManager : NSObject

/**
 *  A block executed when when any integration's status changes.
 */
@property (copy) void (^installStatusDidChangeHandler)(LGIntegrationManager *aManager, LGIntegration *changedIntegration);

/**
 *  Get an array of all the associated integrations
 *
 *  @return Array of subclassed LGIntegrations
 */
@property (strong, readonly) NSArray *allIntegrations;

/**
 *  Get an array of all installed associated integrations;
 *  @note if the integrations +isInstalled method retruns NO, the integration will not be added to the array.
 *
 *  @return Array of installed subclassed LGIntegrations
 */
@property (strong, readonly) NSArray *installedIntegrations;

/**
 *  Get an array of all installed associated integrations;
 *  @note if the integrations +isInstalled method retruns NO, the integration will not be added to the array.
 *
 *  @return Array of installed subclassed LGIntegrations
 */
@property (strong, readonly) NSArray *requiredIntegrations;

/**
 *  Get an array of all installed or requried associated integrations;
 *  @note if the integrations +isInstalled method retruns NO, the integration will not be added to the array.
 *
 *  @return Array of installed subclassed LGIntegrations
 */
@property (strong, readonly) NSArray *installedOrRequiredIntegrations;

/**
 *  Get an array of all installed associated integrations;
 *  @note if the integrations +isInstalled method retruns NO, the integration will not be added to the array.
 *
 *  @return Array of installed subclassed LGIntegrations
 */
@property (strong, readonly) NSArray *optionalIntegrations;

/**
 *  Return the instance of the LGIntegration for a particular class.
 *
 *  @param integrationClass Subclass of the LGIntegration to obtain an instance for.
 *
 *  @return LGIntegration (subclass) instance.
 */
- (id)integrationOfClass:(Class)integrationClass;

/**
 *  Check if required items are installed
 *
 *  @return YES if all required integrations are installed.
 */
+ (BOOL)requiredItemsInstalled;

/**
 *  Display NSAlert indicating requirements
 *
 *  @param window Modal window used for the alert. Can be nil.
 */
+ (void)displayRequirementsAlertOnWindow:(NSWindow *)window;

@end
