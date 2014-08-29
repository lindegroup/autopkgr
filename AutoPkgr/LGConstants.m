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

#pragma mark - App Names
NSString *const kLGApplicationName = @"AutoPkgr";
NSString *const kLGAutoPkgPreferenceDomain = @"com.github.autopkg";
NSString *const kLGAutoPkgrPreferenceDomain = @"com.lindegroup.AutoPkgr";

#pragma mark - Message Strings / Labels
NSString *const kLGGitInstalledLabel = @"Git has been installed.";
NSString *const kLGGitNotInstalledLabel = @"Git is not installed.";
NSString *const kLGAutoPkgInstalledLabel = @"AutoPkg has been installed.";
NSString *const kLGAutoPkgNotInstalledLabel = @"AutoPkg is not installed.";
NSString *const kLGAutoPkgUpdateAvailableLabel = @"An update is available for AutoPkg.";

#pragma mark - Static URLs
NSString *const kLGAutoPkgReleasesJSONURL = @"https://api.github.com/repos/autopkg/autopkg/releases";
NSString *const kLGAutoPkgDownloadURL = @"https://github.com/autopkg/autopkg/zipball/master";
NSString *const kLGAutoPkgRepositoriesJSONURL = @"https://api.github.com/orgs/autopkg/repos";

#pragma mark - Defaults
NSString *const kLGSMTPServer = @"SMTPServer";
NSString *const kLGSMTPPort = @"SMTPPort";
NSString *const kLGSMTPUsername = @"SMTPUsername";
NSString *const kLGSMTPPassword = @"SMTPPassword";
NSString *const kLGSMTPFrom = @"SMTPFrom";
NSString *const kLGSMTPTo = @"SMTPTo";
NSString *const kLGPlistEditor = @"PlistEditor";
NSString *const kLGAutoPkgRunInterval = @"AutoPkgRunInterval";
NSString *const kLGAutoPkgMunkiRepoPath = @"AutoPkgMunkiRepoPath";

NSString *const kLGSMTPTLSEnabled = @"SMTPTLSEnabled";
NSString *const kLGSMTPAuthenticationEnabled = @"SMTPAuthenticationEnabled";
NSString *const kLGHasCompletedInitialSetup = @"HasCompletedInitialSetup";
NSString *const kLGSendEmailNotificationsWhenNewVersionsAreFoundEnabled = @"SendEmailNotificationsWhenNewVersionsAreFoundEnabled";
NSString *const kLGCheckForNewVersionsOfAppsAutomaticallyEnabled = @"CheckForNewVersionsOfAppsAutomaticallyEnabled";
NSString *const kLGCheckForRepoUpdatesAutomaticallyEnabled = @"CheckForRepoUpdatesAutomaticallyEnabled";
NSString *const kLGWarnBeforeQuittingEnabled = @"WarnBeforeQuitting";

#pragma mark - Notifications
#pragma mark -- Progress
NSString *const kLGNotificationProgressStart = @"com.lindegroup.autopkgr.notification.progress.start";
NSString *const kLGNotificationProgressStop = @"com.lindegroup.autopkgr.notification.progress.stop";
NSString *const kLGNotificationProgressMessageUpdate = @"com.lindegroup.autopkgr.progress.message.notification";

#pragma mark -- AutoPkg Task
NSString *const kLGNotificationRunAutoPkgComplete = @"com.lindegroup.autopkgr.notification.autopkgrun.complete";
NSString *const kLGNotificationUpdateReposComplete = @"com.lindegroup.autopkgr.notification.updaterepos.complete";
NSString *const kLGNotificationOverrideFileCreated = @"com.lindegroup.autopkgr.notification.override.file.addorremoved";

#pragma mark -- Email
NSString *const kLGNotificationEmailSent = @"com.lindegroup.autopkgr.email.sent.notification";
NSString *const kLGNotificationTestSmtpServerPort = @"com.lindegroup.autopkgr.test.smpt.port.notification";

#pragma mark -- UserInfo dict keys
NSString *const kLGNotificationUserInfoError = @"com.lindegroup.autopkgr.notification.userinfo.error";
NSString *const kLGNotificationUserInfoMessage = @"com.lindegroup.autopkgr.notification.userinfo.message";
NSString *const kLGNotificationUserInfoSuccess = @"com.lindelgroup.autopkgr.notification.userinfo.success";
NSString *const kLGNotificationUserInfoSubject = @"com.lindelgroup.autopkgr.notification.userinfo.subject";



