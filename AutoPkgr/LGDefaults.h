//
//  LGDefaults.h
//  AutoPkgr
//
//  Created by Eldon on 8/5/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

typedef NS_ENUM(NSInteger, LGApplicationDisplayStyle) {
    kLGDisplayStyleShowNone,
    kLGDisplayStyleShowMenu = 1 << 0,
    kLGDisplayStyleShowDock = 1 << 1,
};

@interface LGDefaults : NSUserDefaults

#pragma mark - Singletons
+ (LGDefaults *)standardUserDefaults;

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

#pragma Class Methods
+ (BOOL)fixRelativePathsInAutoPkgDefaults:(NSError **)error neededFixing:(NSInteger *)neededFixing;
@end
