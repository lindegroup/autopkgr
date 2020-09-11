//
//  LGDefaults.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/5/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

typedef NS_OPTIONS(NSInteger, LGApplicationDisplayStyle) {
    kLGDisplayStyleShowNone,
    kLGDisplayStyleShowMenu = 1 << 0,
    kLGDisplayStyleShowDock = 1 << 1,
};

typedef NS_OPTIONS(NSInteger, LGReportItems) {
    kLGReportItemsNone = 0,
    kLGReportItemsAll = 1 << 0,
    kLGReportItemsNewDownloads = 1 << 1,
    kLGReportItemsNewPackages = 1 << 2,
    kLGReportItemsNewInstalls = 1 << 3,
    kLGReportItemsErrors = 1 << 4,
    kLGReportItemsFailures = 1 << 5,
    kLGReportItemsIntegrationImports = 1 << 6,
    kLGReportItemsIntegrationUpdates = 1 << 7,
};

@interface LGDefaults : NSUserDefaults

#pragma mark - Singletons
+ (instancetype)standardUserDefaults;

#pragma mark - Settings
@property (copy, nonatomic) NSString *SMTPServer;
@property (nonatomic) NSInteger SMTPPort;
@property (copy, nonatomic) NSString *SMTPUsername;
@property (copy, nonatomic) NSString *SMTPFrom;
@property (copy, nonatomic) NSArray *SMTPTo;

#pragma mark - Info
/**
 *  You can pass in either an NSDate object, or NSString and it will return a formatted date string
 */
@property (copy, nonatomic) id LastAutoPkgRun;

/**
 *  Binary shifted values representing the keys to include in the emailed report
 */
@property (assign, nonatomic) LGReportItems reportedItemFlags;

#pragma mark - BOOL
@property (nonatomic) BOOL SMTPTLSEnabled;
@property (nonatomic) BOOL SMTPAuthenticationEnabled;
@property (nonatomic) BOOL hasCompletedInitialSetup;
@property (nonatomic) NSInteger applicationDisplayStyle;

@property (nonatomic) BOOL sendEmailNotificationsWhenNewVersionsAreFoundEnabled;
@property (nonatomic) BOOL checkForRepoUpdatesAutomaticallyEnabled;

#pragma mark - AutoPkg Defaults
@property (nonatomic) NSInteger autoPkgRunInterval;
@property (copy, nonatomic) NSString *autoPkgCacheDir;
@property (copy, nonatomic) NSString *autoPkgRecipeOverridesDir;
@property (copy, nonatomic) NSString *munkiRepo;
@property (copy, nonatomic) NSString *gitPath;
@property (copy, nonatomic) NSString *autoPkgRecipeRepoDir;
@property (copy, nonatomic, readonly) NSArray *autoPkgRecipeSearchDirs;
@property (copy, nonatomic, readonly) NSDictionary *autoPkgRecipeRepos;

#pragma mark - Utility Settings
@property (nonatomic) BOOL debug;

#pragma mark - AutoPkg Accessor methods
- (id)autoPkgDomainObject:(NSString *)key;
- (void)setAutoPkgDomainObject:(id)object forKey:(NSString *)key;

#pragma mark - SimpleMDM Accessor methods
- (id)simpleMDMDomainObject:(NSString *)key;
- (void)setSimpleMDMDomainObject:(id)object forKey:(NSString *)key;

#pragma Class Methods
+ (BOOL)fixRelativePathsInAutoPkgDefaults:(NSError **)error neededFixing:(NSInteger *)neededFixing;

+ (NSString *)formattedDate:(NSDate *)date;

@end
