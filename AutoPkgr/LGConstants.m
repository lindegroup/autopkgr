//
//  LGConstants.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGConstants.h"

NSString *const kApplicationName = @"AutoPkgr";
NSString *const kSMTPServer = @"SMTPServer";
NSString *const kSMTPPort = @"SMTPPort";
NSString *const kSMTPUsername = @"SMTPUsername";
NSString *const kSMTPPassword = @"SMTPPassword";
NSString *const kSMTPFrom = @"SMTPFrom";
NSString *const kSMTPTo = @"SMTPTo";
NSString *const kAutoPkgRunInterval = @"AutoPkgRunInterval";
NSString *const kLocalMunkiRepoPath = @"LocalMunkiRepoPath";
NSString *const kAutoPkgReleasesJSONURL = @"https://api.github.com/repos/autopkg/autopkg/releases";
NSString *const kAutoPkgRepositoriesJSONURL = @"https://api.github.com/orgs/autopkg/repos";
NSString *const kSMTPTLSEnabled = @"SMTPTLSEnabled";
NSString *const kSMTPAuthenticationEnabled = @"SMTPAuthenticationEnabled";
NSString *const kWarnBeforeQuittingEnabled = @"WarnBeforeQuitting";
NSString *const kHasCompletedInitialSetup = @"HasCompletedInitialSetup";
NSString *const kSendEmailNotificationsWhenNewVersionsAreFoundEnabled = @"SendEmailNotificationsWhenNewVersionsAreFoundEnabled";
NSString *const kCheckForNewVersionsOfAppsAutomaticallyEnabled = @"CheckForNewVersionsOfAppsAutomaticallyEnabled";
NSString *const kCheckForRepoUpdatesAutomaticallyEnabled = @"CheckForRepoUpdatesAutomaticallyEnabled";
NSString *const kGitInstalledLabel = @"Git has been installed.";
NSString *const kGitNotInstalledLabel = @"Git is not installed.";
NSString *const kAutoPkgInstalledLabel = @"AutoPkg has been installed.";
NSString *const kAutoPkgNotInstalledLabel = @"AutoPkg is not installed.";
NSString *const kAutoPkgUpdateAvailableLabel = @"An update is available for AutoPkg.";
