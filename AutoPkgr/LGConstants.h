//
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

#import "LGError.h"

extern NSString *const kApplicationName;
extern NSString *const kSMTPServer;
extern NSString *const kSMTPPort;
extern NSString *const kSMTPUsername;
extern NSString *const kSMTPPassword;
extern NSString *const kSMTPFrom;
extern NSString *const kSMTPTo;
extern NSString *const kAutoPkgRunInterval;
extern NSString *const kLocalMunkiRepoPath;
extern NSString *const kAutoPkgReleasesJSONURL;
extern NSString *const kSMTPTLSEnabled;
extern NSString *const kSMTPAuthenticationEnabled;
extern NSString *const kWarnBeforeQuittingEnabled;
extern NSString *const kHasCompletedInitialSetup;
extern NSString *const kSendEmailNotificationsWhenNewVersionsAreFoundEnabled;
extern NSString *const kCheckForNewVersionsOfAppsAutomaticallyEnabled;
extern NSString *const kCheckForRepoUpdatesAutomaticallyEnabled;
extern NSString *const kGitInstalledLabel;
extern NSString *const kGitNotInstalledLabel;
extern NSString *const kAutoPkgInstalledLabel;
extern NSString *const kAutoPkgNotInstalledLabel;
extern NSString *const kAutoPkgUpdateAvailableLabel;
extern NSString *const kEmailSentNotification;
extern NSString *const kEmailSentNotificationSubject;
extern NSString *const kEmailSentNotificationMessage;
extern NSString *const kEmailSentNotificationError;
extern NSString *const kTestSmtpServerPortNotification;
extern NSString *const kTestSmtpServerPortError;
extern NSString *const kTestSmtpServerPortSuccess;
extern NSString *const kTestSmtpServerPortResult;

extern NSString *const kRunAutoPkgCompleteNotification;
extern NSString *const kUpdateReposCompleteNotification;
extern NSString *const kProgressStartNotification;
extern NSString *const kProgressStopNotification;
extern NSString *const kProgressMessageUpdateNotification;
extern NSString *const kNotificationUserInfoError;
extern NSString *const kNotificationUserInfoMessage;
