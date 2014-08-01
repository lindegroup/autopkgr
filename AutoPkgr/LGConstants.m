//
//  LGConstants.m
//  AutoPkgr
//
//  Created by James Barclay on 6/26/14.
//  Copyright (c) 2014 The Linde Group, Inc. All rights reserved.
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
NSString *const kEmailSentNotification = @"EmailSentNotification";
NSString *const kEmailSentNotificationSubject = @"EmailSentNotificationSubject";
NSString *const kEmailSentNotificationMessage = @"EmailSentNotificationMessage";
NSString *const kEmailSentNotificationError = @"EmailSentNotificationError";
NSString *const kTestSmtpServerPortNotification = @"TestSmtpServerPortNotification";
NSString *const kTestSmtpServerPortError = @"TestSmtpServerPortError";
NSString *const kTestSmtpServerPortSuccess = @"TestSmtpServerPortSuccess";
NSString *const kTestSmtpServerPortResult = @"TestSmtpServerPortResult";

NSString *const kRunAutoPkgCompleteNotification = @"com.lindegroup.autopkgr.autopkgruncomplete";
NSString *const kUpdateReposCompleteNotification = @"com.lindegroup.autopkgr.updatereposcomplete";
NSString *const kProgressStartNotification = @"com.lindegroup.autopkgr.progress.start.notification";
NSString *const kProgressStopNotification = @"com.lindegroup.autopkgr.progress.stop.notification";

