//
//  LGConstants.h
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
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

#pragma mark - App Names
extern NSString *const kLGApplicationName;
extern NSString *const kLGAutoPkgPreferenceDomain;
extern NSString *const kLGAutoPkgrPreferenceDomain;
extern NSString *const kLGAutoPkgrHelperToolName;
extern NSString *const kLGAutoPkgrLaunchDaemonPlist;

#pragma mark - String Tables
extern NSString *const kLGLocalizedHelpTable;

#pragma mark - Static URLs
extern NSString *const kLGAutoPkgReleasesJSONURL;
extern NSString *const kLGGitReleasesJSONURL;
extern NSString *const kLGJSSImporterJSONURL;
extern NSString *const kLGAutoPkgRepositoriesJSONURL;
extern NSString *const kLGJSSDefaultRepo;
extern NSString *const kLGAutoPkgrWebsite;
extern NSString *const kLGAutoPkgrHelpWebsite;

#pragma mark - Defaults
extern NSString *const kLGSMTPServer;
extern NSString *const kLGSMTPPort;
extern NSString *const kLGSMTPUsername;
extern NSString *const kLGSMTPPassword;
extern NSString *const kLGSMTPFrom;
extern NSString *const kLGSMTPTo;
extern NSString *const kLGPlistEditor;
extern NSString *const kLGAutoPkgRunInterval;
extern NSString *const kLGAutoPkgMunkiRepoPath;
extern NSString *const kLGHasCompletedInitialSetup;
extern NSString *const kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled;
extern NSString *const kLGCheckForNewVersionsOfAppsAutomaticallyEnabled;
extern NSString *const kLGCheckForRepoUpdatesAutomaticallyEnabled;
extern NSString *const kLGSMTPTLSEnabled;
extern NSString *const kLGSMTPAuthenticationEnabled;
extern NSString *const kLGWarnBeforeQuittingEnabled;
extern NSString *const kLGApplicationDisplayStyle;

#pragma mark - Notifications
#pragma mark-- Progress
extern NSString *const kLGNotificationProgressStart;
extern NSString *const kLGNotificationProgressStop;
extern NSString *const kLGNotificationProgressMessageUpdate;

#pragma mark-- AutoPkg Task
extern NSString *const kLGNotificationRunAutoPkgComplete;
extern NSString *const kLGNotificationUpdateReposComplete;
extern NSString *const kLGNotificationOverrideFileCreated;
extern NSString *const kLGNotificationReposModified;

#pragma mark-- Email
extern NSString *const kLGNotificationEmailSent;
extern NSString *const kLGNotificationTestSmtpServerPort;

#pragma mark-- UserInfo dict keys
//* key corresponding to NSError object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoError;
//* key corresponding to a message string object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoMessage;
//* key corresponding to the total recipe count in Notification's userInfo dictionary during an AutoPkgr run task */
extern NSString *const kLGNotificationUserInfoTotalRecipeCount;
//* key corresponding to NSNumber BOOL object in Notification's userInfo dictionary, indicating success/failure */
extern NSString *const kLGNotificationUserInfoSuccess;
//* key corresponding to Subject object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoSubject;
//* key corresponding to Progress object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoProgress;
