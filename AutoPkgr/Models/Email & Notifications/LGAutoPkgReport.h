//
//  LGAutoPkgReport.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/22/15.
//  Copyright 2015 The Linde Group, Inc.
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
#import "LGAutoPkgr.h"

@class LGIntegration;

typedef NS_ENUM(NSInteger, LGReportIntegrationFrequency) {
    // Send a report for any give update once a week (Default)
    kLGReportIntegrationFrequencyWeekly = 0,

    // Send a report for any give update once a day
    kLGReportIntegrationFrequencyDaily,

    // Send a report only once per version
    kLGReportIntegrationFrequencyOncePerVersion,
};
/**
 *  Class to construct formatted messages from defined attributes.
 */
@interface LGAutoPkgReport : NSObject

/**
 *  Initialize the report with an AutoPkg(r) --report-plist dictionary
 *
 *  @param dictionary Dictionary representation of --report-plist output
 *
 *  @return Initialized LGAutoPkgReport object
 */
- (instancetype)initWithReportDictionary:(NSDictionary *)dictionary;

/**
 *  Dictionary representation of --report-plist output
 */
@property (copy, nonatomic) NSDictionary *autoPkgReport;

/**
 *  Error object to parse
 */
@property (copy, nonatomic) NSError *error;

/**
 *  Array of LGIntegrations
 */
@property (copy, nonatomic) NSArray<LGIntegration *> *integrations;

/**
 *  Flags to define what to display in the report
 */
@property (assign, nonatomic) LGReportItems reportedItemFlags;

/**
 *  Check to determine if there is anything to report
 */
@property (nonatomic, readonly) BOOL updatesToReport;

/**
 *  Subject of message, follows importance updates -> failures -> errors -> updates to integrations.
 */
@property (copy, nonatomic, readonly) NSString *reportSubject;

/**
 *  NSDictionary representing the data usable to the templating system.
 *  AutoPkgr pops know processor summary results to the top level for easier and more succinct templating.
 */
@property (copy, nonatomic, readonly) NSDictionary *templateData;

/**
 *  Render a completed message using a given template.
 *
 *  @param templateString Raw mustache style template string.
 *  @param error Populated NSError should an error occur rendering
 *
 *  @return Fully formatted message. 
 */
- (NSString *)renderWithTemplate:(NSString *)templateString error:(NSError **)error;

#pragma mark - Additional
/**
 *  Array of LGUpdatedApplications
 */
@property (copy, nonatomic, readonly) NSArray *updatedApplications;

/**
 *  Failure results array from report converted into an NSError object
 */
@property (copy, nonatomic, readonly) NSError *failureError;

@end

@interface LGUpdatedApplication : NSObject

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (copy, nonatomic, readonly) NSString *dictionaryRepresentation;
@property (copy, nonatomic, readonly) NSString *name;
@property (copy, nonatomic, readonly) NSString *version;
@property (copy, nonatomic, readonly) NSString *path;

@end
