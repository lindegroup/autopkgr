//  LGConstants.h
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

#pragma mark - App Names
extern NSString *const kLGApplicationName;
extern NSString *const kLGAutoPkgPreferenceDomain;
extern NSString *const kLGAutoPkgrPreferenceDomain;

#pragma mark - Message Strings / Labels
extern NSString *const kLGGitInstalledLabel;
extern NSString *const kLGGitNotInstalledLabel;
extern NSString *const kLGAutoPkgInstalledLabel;
extern NSString *const kLGAutoPkgNotInstalledLabel;
extern NSString *const kLGAutoPkgUpdateAvailableLabel;

#pragma mark - Static URLs
extern NSString *const kLGAutoPkgReleasesJSONURL;
extern NSString *const kLGAutoPkgDownloadURL;
extern NSString *const kLGAutoPkgRepositoriesJSONURL;

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

#pragma mark - Notifications
#pragma mark -- Progress
extern NSString *const kLGNotificationProgressStart;
extern NSString *const kLGNotificationProgressStop;
extern NSString *const kLGNotificationProgressMessageUpdate;

#pragma mark -- AutoPkg Task
extern NSString *const kLGNotificationRunAutoPkgComplete;
extern NSString *const kLGNotificationUpdateReposComplete;
extern NSString *const kLGNotificationOverrideFileCreated;

#pragma mark -- Email
extern NSString *const kLGNotificationEmailSent;
extern NSString *const kLGNotificationTestSmtpServerPort;

#pragma mark -- UserInfo dict keys
//* key cooresponding to NSError object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoError;
//* key cooresponding to a message string object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoMessage;
//* key cooresponding to a the total recipe count in Notification's userInfo dictionary during an autopkgr run task*/
extern NSString *const kLGNotificationUserInfoTotalRecipeCount;
//* key cooresponding to NSNumber BOOL object in Notification's userInfo dictionary, indicating success/failure */

extern NSString *const kLGNotificationUserInfoSuccess;
//* key cooresponding to NSError object in Notification's userInfo dictionary */
extern NSString *const kLGNotificationUserInfoSubject;