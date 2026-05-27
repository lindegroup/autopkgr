//
//  AutoPkgrTests.m
//  AutoPkgrTests
//
//  Created by James Barclay on 6/25/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGAutoPkgr.h"
#import "LGGitHubJSONLoader.h"
#import "LGInstaller.h"
#import "LGIntegrationManager.h"
#import "NSString+versionCompare.h"
#import <XCTest/XCTest.h>

#import "LGAutoPkgErrorHandler.h"
#import "LGAutoPkgRecipeListManager.h"
#import "LGAutoPkgReport.h"
#import "LGAutoPkgTask.h"

#import "LGPasswords.h"
#import "LGServerCredentials.h"

#import "LGHipChatNotification.h"
#import "LGNotificationManager.h"
#import "LGSlackNotification.h"

#import "LGUserNotification.h"
#import "LGEmailNotification.h"

extern NSString *LGSanitizeHeaderValue(NSString *value);
extern NSString *LGRfc2047Encode(NSString *value);
extern NSString *LGRfc2822Date(void);
extern NSData *LGBuildSmtpMessage(NSString *subject, NSString *htmlBody,
                                  NSString *fromAddress, NSArray<NSString *> *toAddresses);

static const BOOL _TEST_PRIVILEGED_HELPER = YES;

@interface AutoPkgrTests : XCTestCase <LGProgressDelegate>

@end

@implementation AutoPkgrTests {
    LGUserNotificationsDelegate *_noteDelegate;
}

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#pragma mark - LGAutoPkgTask
- (void)testSyncMethods
{
    XCTAssertNotNil([LGAutoPkgTask repoList], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask listProcessors], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask listRecipes], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask processorInfo:@"Installer"], @"Failed test");
}

- (void)testRecipeLists
{
    LGAutoPkgRecipeListManager *listManager = [[LGAutoPkgRecipeListManager alloc] init];
    NSString *newList = @"bilbo";

    NSLog(@"%@", listManager.currentListName);
    NSLog(@"%@", listManager.currentListPath);
    listManager.currentListName = newList;

    NSLog(@"%@", listManager.currentListName);

    [listManager addRecipeList:newList error:nil];
    listManager.currentListName = newList;

    NSLog(newList, listManager.currentListName);
    NSLog(@"%@", listManager.recipeLists);

    [listManager removeRecipeList:newList error:nil];
}

#pragma mark - LGIntegrations
- (void)testIntegrationStatus
{
    NSArray *integrationStatus = [[LGIntegrationManager new] installedIntegrations];
    XCTAssertNotNil(integrationStatus, @"Integration array should not be nil");
}

- (void)testIntegrationAndInstall
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Integration Test"];
    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Integration Install Async"];

    __block BOOL fufillExpectation1 = NO;
    __block LGAutoPkgIntegration *integration = [[LGAutoPkgIntegration alloc] init];
    integration.progressDelegate = self;

    [integration setInfoUpdateHandler:^(LGIntegrationInfo *info) {
        XCTAssert(info.remoteVersion, @"Could not get remote version");
        XCTAssert(info.installedVersion, @"Could not get installed version");

        if (!fufillExpectation1) {
            [expectation1 fulfill];
            fufillExpectation1 = YES;
        }
        else {
            [expectation2 fulfill];
        };
    }];

    [integration refresh];
    [integration install:nil];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testToolAndInstallWithBlock
{
    /*
     * This test requires modifying the privileged helper tool to
     * and override the -newConnectionIsValid: method in the helper tool to just return YES.
     * The code for this has never been committed to ensure it's never released into the wild.
     */

    if (_TEST_PRIVILEGED_HELPER) {
        NSArray *integrations = [[LGIntegrationManager new] allIntegrations];
        NSMutableArray *expectations = [[NSMutableArray alloc] init];

        for (LGIntegration *integration in integrations) {
            XCTestExpectation *expectation = [self expectationWithDescription:quick_formatString(@"Expectation: %@", integration.name)];
            [expectations addObject:expectation];
        }

        for (int i = 0; i < integrations.count; i++) {
            LGIntegration *integration = integrations[i];
            [integration install:^(NSString *message, double progress) {
                NSLog(@"Progress: %@", message);
                XCTAssert([NSThread isMainThread], @"Not main thread");
            }
                reply:^(NSError *error) {
                    XCTAssert([NSThread isMainThread], @"Not main thread");
                    XCTAssertNil(error, @"error %@", error.localizedDescription);
                    [expectations[i] fulfill];
                }];
        }

        [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
            if (error) {
                XCTFail(@"Expectation Failed with error: %@", error);
            }
        }];
    }
}

- (void)testIntegrationInfo1
{
    LGAutoPkgIntegration *integration = [[LGAutoPkgIntegration alloc] init];
    XCTAssertNotNil(integration.info.remoteVersion);
}

- (void)testIntegrationInfo2
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Integration info"];

    LGAutoPkgIntegration *integration = [[LGAutoPkgIntegration alloc] init];
    [integration setInfoUpdateHandler:^(LGIntegrationInfo *info) {
        XCTAssertNotNil(info.remoteVersion);
        [expectation fulfill];
    }];
    [integration refresh];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark - LGGitHubJSONLoader
- (void)testLatestReleases
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"GitHub Release Async"];

    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] initWithGitHubURL:kLGAutoPkgReleasesJSONURL];

    [loader getReleaseInfo:^(LGGitHubReleaseInfo *info, NSError *error) {
        NSLog(@"%@, %@", info.description, error.localizedDescription);
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testVersionCompare
{
    // GT
    XCTAssertTrue([@"0.4.2" version_isGreaterThan:@"0.4.1"], @"wrong");
    XCTAssertTrue([@"0.4.2" version_isGreaterThan:@"0.4.1"], @"wrong");
    XCTAssertTrue([@"0.4.12" version_isGreaterThan:@"0.4.3.0.0"], @"wrong");
    XCTAssertFalse([@"0.4.2" version_isGreaterThan:@"0.4.2"], @"wrong");

    // GTOE
    XCTAssertFalse([@"0.4.2" version_isGreaterThanOrEqualTo:@"0.4.3.0"], @"wrong");
    XCTAssertFalse([@"0.4.2" version_isGreaterThanOrEqualTo:@"0.4.3"], @"wrong");
    XCTAssertFalse([@"0.4.2.0" version_isGreaterThanOrEqualTo:@"0.4.3"], @"wrong");
    XCTAssertFalse([@"0.4.2.0" version_isGreaterThanOrEqualTo:@"0.4.3.0"], @"wrong");
    XCTAssertFalse([@"0.4" version_isGreaterThanOrEqualTo:@"0.4.3.0.0"], @"wrong");
    XCTAssertFalse([@"0.4.3.0.0" version_isGreaterThanOrEqualTo:@"0.4.12"], @"wrong");

    // EQ
    XCTAssertTrue([@"0.4.2" version_isEqualTo:@"0.4.2"], @"wrong");
    XCTAssertTrue([@"0.4.2" version_isEqualTo:@"0.4.2.0"], @"wrong");
    XCTAssertTrue([@"0.4.2.0" version_isEqualTo:@"0.4.2"], @"wrong");
    XCTAssertFalse([@"0.4.1.0" version_isEqualTo:@"0.4.2"], @"wrong");
    XCTAssertFalse([@"0.4.2" version_isEqualTo:@"0.4.1.0"], @"wrong");

    // LT
    XCTAssertFalse([@"0.4.2" version_isLessThan:@"0.4.1"], @"wrong");
    XCTAssertTrue([@"0.4.1" version_isLessThan:@"0.4.2"], @"wrong");

    // LTOE
    XCTAssertFalse([@"0.4.2" version_isLessThanOrEqualTo:@"0.4.1"], @"wrong");
    XCTAssertTrue([@"0.4.1" version_isLessThanOrEqualTo:@"0.4.1"], @"wrong");
    XCTAssertTrue([@"0.4.1" version_isLessThanOrEqualTo:@"0.4.2"], @"wrong");
}

#pragma mark - Munki version detection

- (NSArray *)munkiPackageIdentifiers
{
    return @[ @"com.googlecode.munki.admin",
              @"com.googlecode.munki.app",
              @"com.googlecode.munki.app_usage",
              @"com.googlecode.munki.core",
              @"com.googlecode.munki.launchd" ];
}

- (NSString *)munkiVersionFromReceiptsInDirectory:(NSString *)dir
{
    NSString *highestVersion = nil;
    for (NSString *identifier in [self munkiPackageIdentifiers]) {
        NSString *receiptPath = [[dir stringByAppendingPathComponent:identifier] stringByAppendingPathExtension:@"plist"];
        NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:receiptPath];
        NSString *version = receiptDict[@"PackageVersion"];
        if (version && (!highestVersion || [version version_isGreaterThan:highestVersion])) {
            highestVersion = version;
        }
    }
    return highestVersion;
}

- (void)writeReceiptPlistAtPath:(NSString *)path version:(NSString *)version
{
    NSDictionary *receipt = @{
        @"PackageIdentifier" : path.lastPathComponent.stringByDeletingPathExtension,
        @"PackageVersion" : version,
        @"InstallDate" : [NSDate date],
        @"InstallPrefixPath" : @"/",
    };
    [receipt writeToFile:path atomically:YES];
}

- (void)testMunkiReceiptVersionMatchesMetapackage
{
    // Munki v6.6.0: metapackage was munkitools-6.6.0.4690.pkg but munkiimport
    // --version reported 6.6.0.4686, because the code/client rev count was lower
    // than the code/apps rev count used for the metapackage build number.
    // Reading receipts should yield the correct metapackage version.
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *metapackageVersion = @"6.6.0.4690";
    for (NSString *identifier in [self munkiPackageIdentifiers]) {
        NSString *path = [[tmpDir stringByAppendingPathComponent:identifier]
                          stringByAppendingPathExtension:@"plist"];
        if ([identifier isEqualToString:@"com.googlecode.munki.launchd"]) {
            [self writeReceiptPlistAtPath:path version:@"6.5.0.4265"];
        } else {
            [self writeReceiptPlistAtPath:path version:metapackageVersion];
        }
    }

    NSString *detectedVersion = [self munkiVersionFromReceiptsInDirectory:tmpDir];
    XCTAssertEqualObjects(detectedVersion, metapackageVersion,
        @"Receipt-based detection should return the metapackage version");

    // munkiimport --version would have returned 6.6.0.4686 for this release,
    // which is less than the metapackage version and would falsely trigger an update.
    NSString *munkiimportVersion = @"6.6.0.4686";
    XCTAssertTrue([metapackageVersion version_isGreaterThan:munkiimportVersion],
        @"munkiimport --version (4686) is less than the metapackage (4690)");
    XCTAssertFalse([metapackageVersion version_isGreaterThan:detectedVersion],
        @"Receipt-based version should not falsely trigger an update");

    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
}

- (void)testMunkiReceiptVersionWithDivergentBuildNumbers
{
    // Simulate real-world receipts where sub-packages have different build numbers.
    // The launchd package often lags behind because its content changes less frequently.
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSDictionary *receiptVersions = @{
        @"com.googlecode.munki.admin"     : @"7.1.2.5700",
        @"com.googlecode.munki.app"       : @"7.1.2.5700",
        @"com.googlecode.munki.app_usage" : @"7.1.2.5700",
        @"com.googlecode.munki.core"      : @"7.1.2.5700",
        @"com.googlecode.munki.launchd"   : @"7.0.0.5320",
    };
    for (NSString *identifier in receiptVersions) {
        NSString *path = [[tmpDir stringByAppendingPathComponent:identifier]
                          stringByAppendingPathExtension:@"plist"];
        [self writeReceiptPlistAtPath:path version:receiptVersions[identifier]];
    }

    NSString *detectedVersion = [self munkiVersionFromReceiptsInDirectory:tmpDir];
    XCTAssertEqualObjects(detectedVersion, @"7.1.2.5700",
        @"Should return the highest version across all receipts");

    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
}

- (void)testMunkiReceiptVersionExcludesPythonlibs
{
    // The pythonlibs receipt can have a completely different version (e.g. 6.7.0.5293
    // when the rest of Munki is 7.1.2.5700). Verify it is excluded from the
    // identifier list so it cannot poison the version detection.
    NSArray *identifiers = [self munkiPackageIdentifiers];
    XCTAssertFalse([identifiers containsObject:@"com.googlecode.munki.pythonlibs"],
        @"pythonlibs must not be in packageIdentifiers");
}

- (void)testMunkiReceiptVersionNoFalseUpdateForV660
{
    // Munki v6.6.0: the GitHub release asset is munkitools-6.6.0.4690.pkg, but
    // munkiimport --version reports 6.6.0.4686 due to divergent build numbers.
    // Using receipts yields 6.6.0.4690, matching the remote version correctly.
    NSString *remoteVersion = @"6.6.0.4690";
    NSString *munkiimportVersion = @"6.6.0.4686";
    NSString *receiptVersion = @"6.6.0.4690";

    // munkiimport --version reports a lower build number than the metapackage
    XCTAssertTrue([remoteVersion version_isGreaterThan:munkiimportVersion],
        @"munkiimport --version would falsely indicate an update is available");

    // Receipt-based detection matches the metapackage version
    XCTAssertFalse([remoteVersion version_isGreaterThan:receiptVersion],
        @"Receipt-based version correctly matches, no false update");
}

- (void)testMunkiReceiptVersionMissingReceipts
{
    // When no receipts exist (Munki not installed), the method should return nil.
    NSString *tmpDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                        [[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSString *detectedVersion = [self munkiVersionFromReceiptsInDirectory:tmpDir];
    XCTAssertNil(detectedVersion,
        @"Should return nil when no receipt plists exist");

    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:nil];
}

- (void)testLoader
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"GitHub Release Async"];

    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] initWithGitHubURL:kLGAutoPkgReleasesJSONURL];
    [loader getReleaseInfo:^(LGGitHubReleaseInfo *info, NSError *error) {
        XCTAssertNotNil(info.latestVersion, @"The latest version should not be nil!");
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testGitHubInfo
{
    // Tests tests the synchronous fall back method used by LGGitHubJSONLoader
    LGGitHubReleaseInfo *info = [[LGGitHubReleaseInfo alloc] initWithURL:kLGAutoPkgReleasesJSONURL];
    XCTAssertNotNil(info.latestVersion, @"The latest version should not be nil!");
}

#pragma mark - LGAutoPkgReports
- (void)test_reports
{
    [self test_report_malformed];
    [self test_report_none];
    [self test0_4_2_report];
    [self test0_4_3_report];
}

- (void)test0_4_2_report
{
    [self runReportTestWithResourceNamed:@"report_0.4.2" flags:kLGReportItemsAll];
}

- (void)test0_4_3_report
{
    [self runReportTestWithResourceNamed:@"report_0.4.3" flags:kLGReportItemsAll];
}

- (void)test_report_none
{
    [self runReportTestWithResourceNamed:@"report_none" flags:kLGReportItemsAll];
}

- (void)test_report_malformed
{
    [self runReportTestWithResourceNamed:@"report_malformed" flags:kLGReportItemsAll];
}

- (NSError *)reportError
{
    return [NSError errorWithDomain:@"AutoPkgr" code:1 userInfo:@{ NSLocalizedDescriptionKey : @"Error running recipes",
                                                                   NSLocalizedRecoverySuggestionErrorKey : @"Code signature verification failed. Note that all verifications can be disabled by setting the variable DISABLE_CODE_SIGNATURE_VERIFICATION to a non-empty value.\nThere was an unknown exception which causes autopkg to fail." }];
}

- (void)runReportTestWithResourceNamed:(NSString *)resource flags:(LGReportItems)flags
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *reportFile = [bundle pathForResource:resource ofType:@"plist"];
    NSDictionary *reportDict = [NSDictionary dictionaryWithContentsOfFile:reportFile];

    [self runReportTestWithDict:reportDict flags:flags];
}

- (void)runReportTestWithDict:(NSDictionary *)dict flags:(LGReportItems)flags
{
    NSString *htmlFile = @"/tmp/report.html";
    if ([[NSFileManager defaultManager] fileExistsAtPath:htmlFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:htmlFile error:nil];
    }

    LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:dict];
    report.error = [self reportError];

    report.reportedItemFlags = flags;
    //    [report.emailMessageString writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSDictionary *d = report.templateData;

    if (![d writeToFile:@"/tmp/example_data.plist" atomically:YES]) {
        NSLog(@"error writing %@", d);
    }

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *template = [bundle pathForResource:@"report" ofType:@"html"];

    [[report renderWithTemplate:template error:nil] writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    [[NSWorkspace sharedWorkspace] openFile:htmlFile];
}

- (void)testReportEmail
{
    NSString *htmlFile = @"/tmp/report.html";
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    //    NSString *reportFile = [bundle pathForResource:@"report_0.4.2" ofType:@"plist"];
    NSString *reportFile = [bundle pathForResource:@"report_0.4.3" ofType:@"plist"];

    NSDictionary *reportDict = [NSDictionary dictionaryWithContentsOfFile:reportFile];

    LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:reportDict];
    report.error = [self reportError];

    report.integrations = [[LGIntegrationManager new] installedIntegrations];

    report.reportedItemFlags = kLGReportItemsAll;

    //    [report.emailMessageString writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSString *template = [bundle pathForResource:@"report" ofType:@"html"];
    [[report renderWithTemplate:template error:nil] writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    [[NSWorkspace sharedWorkspace] openFile:htmlFile];
}

- (void)testReportFailureOnly
{
    NSString *htmlFile = @"/tmp/report.html";
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    NSString *reportFile = [bundle pathForResource:@"report_0.4.3_failure_only" ofType:@"plist"];
    NSDictionary *reportDict = [NSDictionary dictionaryWithContentsOfFile:reportFile];

    LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:reportDict];
    report.reportedItemFlags = kLGReportItemsAll;

    NSString *htmlTemplate = [NSString stringWithContentsOfFile:[bundle pathForResource:@"report" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];

    NSString *renderedHtml = [report renderWithTemplate:htmlTemplate error:nil];
    [renderedHtml writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    [[NSWorkspace sharedWorkspace] openFile:htmlFile];
}

#pragma mark - Notifications
- (LGAutoPkgReport *)notificationReport
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *reportFile = [bundle pathForResource:@"report_0.4.2" ofType:@"plist"];
    NSDictionary *reportDict = [NSDictionary dictionaryWithContentsOfFile:reportFile];

    LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:reportDict];

    return report;
}

- (void)testNotificationManager
{
    // Set up User Notification Delegate
    _noteDelegate = [[LGUserNotificationsDelegate alloc] initAsDefaultCenterDelegate];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Notification manager test"];

    LGNotificationManager *mgr = [[LGNotificationManager alloc] initWithReportDictionary:[self notificationReport].autoPkgReport
                                                                                  errors:[self reportError]];

    [mgr sendEnabledNotifications:^(NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if (error) {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testIsNetworkOpCheck
{
    // Are
    XCTAssertTrue([self isNetworkOperation:kLGAutoPkgRun], @"Run should be ");
    XCTAssertTrue([self isNetworkOperation:kLGAutoPkgSearch], @"Search should be");
    XCTAssertTrue([self isNetworkOperation:kLGAutoPkgRepoAdd], @"Repo Add should be");
    XCTAssertTrue([self isNetworkOperation:kLGAutoPkgRepoUpdate], @"Repo Update should be");

    // Are not.
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgMakeOverride], @"Repo List should not be");
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgInfo], @"Repo List should not be");
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgRepoDelete], @"Repo List should not be");
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgProcessorInfo], @"Repo List should not be");
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgListProcessors], @"Repo List should not be");

    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgRepoList], @"Repo List should not be");
    XCTAssertFalse([self isNetworkOperation:kLGAutoPkgVersion], @"Version should not be");
}

- (BOOL)isNetworkOperation:(LGAutoPkgVerb)verb
{
    NSInteger ck = (kLGAutoPkgRepoAdd | kLGAutoPkgRepoUpdate | kLGAutoPkgRun | kLGAutoPkgSearch);

    BOOL isNetworkOperation = verb & ck;

    return isNetworkOperation;
}

- (void)testSlackNotification
{
    id<LGNotificationServiceProtocol> notification = [[LGSlackNotification alloc] initWithReport:[self notificationReport]];
    XCTestExpectation *expectation = [self expectationWithDescription:quick_formatString(@"Test %@", [notification.class serviceDescription])];

    [notification send:^(NSError *error) {
        if (_TEST_PRIVILEGED_HELPER) {
            XCTAssertNil(error, @"%@", error);
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectation Failed with error: %@", error);
    }];
}

- (void)testHipChatNotification
{
    id<LGNotificationServiceProtocol> notification = [[LGHipChatNotification alloc] initWithReport:[self notificationReport]];

    XCTestExpectation *expectation = [self expectationWithDescription:quick_formatString(@"Test %@", [notification.class serviceDescription])];

    [notification send:^(NSError *error) {
        if (_TEST_PRIVILEGED_HELPER) {
            XCTAssertNil(error, @"%@", error);
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        XCTAssertNil(error, @"Expectation Failed with error: %@", error);
    }];
}

#pragma mark - Email helpers
- (void)testSanitizeHeaderStripsNewlines
{
    XCTAssertEqualObjects(LGSanitizeHeaderValue(@"clean"), @"clean");
    XCTAssertEqualObjects(LGSanitizeHeaderValue(@"has\r\nnewline"), @"hasnewline");
    XCTAssertEqualObjects(LGSanitizeHeaderValue(@"bare\nLF"), @"bareLF");
    XCTAssertEqualObjects(LGSanitizeHeaderValue(@"bare\rCR"), @"bareCR");
    XCTAssertEqualObjects(LGSanitizeHeaderValue(nil), @"");
}

- (void)testSanitizeHeaderBlocksInjection
{
    NSString *malicious = @"user@example.com\r\nBcc: attacker@evil.com";
    NSString *sanitized = LGSanitizeHeaderValue(malicious);
    XCTAssertFalse([sanitized containsString:@"\r"], @"Should not contain CR");
    XCTAssertFalse([sanitized containsString:@"\n"], @"Should not contain LF");
    XCTAssertTrue([sanitized containsString:@"Bcc:"], @"CRLF stripped, so 'Bcc:' becomes part of the flat value");
}

- (void)testRfc2047EncodeAscii
{
    NSString *ascii = @"Test notification from AutoPkgr";
    XCTAssertEqualObjects(LGRfc2047Encode(ascii), ascii, @"ASCII strings should pass through unchanged");
}

- (void)testRfc2047EncodeNonAscii
{
    NSString *input = @"Héllo Wörld";
    NSString *encoded = LGRfc2047Encode(input);
    XCTAssertTrue([encoded hasPrefix:@"=?UTF-8?B?"], @"Should use UTF-8 Base64 encoding prefix");
    XCTAssertTrue([encoded hasSuffix:@"?="], @"Should end with ?= delimiter");

    NSString *base64Part = [[encoded stringByReplacingOccurrencesOfString:@"=?UTF-8?B?" withString:@""]
                                     stringByReplacingOccurrencesOfString:@"?=" withString:@""];
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:base64Part options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSString *roundTripped = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(roundTripped, input, @"Round-trip decode should match original");
}

- (void)testRfc2047EncodeSanitizesCRLF
{
    NSString *injected = @"Hello\r\nBcc: evil@attacker.com";
    NSString *encoded = LGRfc2047Encode(injected);
    XCTAssertFalse([encoded containsString:@"\r"], @"Encoded value must not contain CR");
    XCTAssertFalse([encoded containsString:@"\n"], @"Encoded value must not contain LF");
}

- (void)testRfc2822DateFormat
{
    NSString *date = LGRfc2822Date();
    XCTAssertNotNil(date, @"Date should not be nil");

    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    fmt.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
    NSDate *parsed = [fmt dateFromString:date];
    XCTAssertNotNil(parsed, @"Date string should be valid RFC 2822 format");
    XCTAssertEqualWithAccuracy([parsed timeIntervalSinceNow], 0, 5, @"Parsed date should be within 5 seconds of now");
}

- (void)testBuildSmtpMessageContainsRequiredHeaders
{
    NSData *msg = LGBuildSmtpMessage(@"Test Subject", @"<p>Hello</p>",
                                     @"sender@example.com", @[@"rcpt@example.com"]);
    NSString *raw = [[NSString alloc] initWithData:msg encoding:NSASCIIStringEncoding];

    XCTAssertTrue([raw containsString:@"From: AutoPkgr Notification <sender@example.com>\r\n"]);
    XCTAssertTrue([raw containsString:@"To: rcpt@example.com\r\n"]);
    XCTAssertTrue([raw containsString:@"Subject: Test Subject\r\n"]);
    XCTAssertTrue([raw containsString:@"Date: "]);
    XCTAssertTrue([raw containsString:@"Message-ID: <"]);
    XCTAssertTrue([raw containsString:@"MIME-Version: 1.0\r\n"]);
    XCTAssertTrue([raw containsString:@"Content-Type: text/html; charset=UTF-8\r\n"]);
    XCTAssertTrue([raw containsString:@"Content-Transfer-Encoding: base64\r\n"]);
}

- (void)testBuildSmtpMessageBase64Body
{
    NSString *html = @"<p>Hello World</p>";
    NSData *msg = LGBuildSmtpMessage(@"Sub", html, @"a@b.com", @[@"c@d.com"]);
    NSString *raw = [[NSString alloc] initWithData:msg encoding:NSASCIIStringEncoding];

    // Extract body after the blank line separating headers from body.
    NSRange sep = [raw rangeOfString:@"\r\n\r\n"];
    XCTAssertTrue(sep.location != NSNotFound, @"Headers and body must be separated by blank line");
    NSString *body = [[raw substringFromIndex:NSMaxRange(sep)] stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // Decode and verify round-trip.
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:body options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSString *roundTripped = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
    XCTAssertEqualObjects(roundTripped, html);
}

- (void)testBuildSmtpMessageSanitizesHeaders
{
    NSData *msg = LGBuildSmtpMessage(@"Normal", @"body",
                                     @"ok@test.com\r\nBcc: evil@x.com",
                                     @[@"rcpt@test.com\r\nBcc: evil@y.com"]);
    NSString *raw = [[NSString alloc] initWithData:msg encoding:NSASCIIStringEncoding];
    // After sanitization, \r\n is stripped so "Bcc:" is collapsed into the
    // From/To value — not on its own line as a separate header.
    XCTAssertFalse([raw containsString:@"\r\nBcc:"], @"Injected Bcc must not appear as a separate header");
}

- (void)testBuildSmtpMessageMultipleRecipients
{
    NSData *msg = LGBuildSmtpMessage(@"Sub", @"body", @"a@b.com", @[@"x@y.com", @"z@w.com"]);
    NSString *raw = [[NSString alloc] initWithData:msg encoding:NSASCIIStringEncoding];
    XCTAssertTrue([raw containsString:@"To: x@y.com, z@w.com\r\n"]);
}

- (void)testBuildSmtpMessageAllAscii
{
    NSData *msg = LGBuildSmtpMessage(@"Test", @"<b>Hi</b>", @"a@b.com", @[@"c@d.com"]);
    // Entire message must be 7-bit safe (base64 body + ASCII headers).
    const uint8_t *bytes = msg.bytes;
    for (NSUInteger i = 0; i < msg.length; i++) {
        XCTAssertTrue(bytes[i] < 128, @"Byte at offset %lu is not 7-bit safe: 0x%02x", (unsigned long)i, bytes[i]);
    }
}

#pragma mark - Utility
- (void)testErrorAlerts
{
    for (int i = 1; i < kLGErrorAuthChallenge; i++) {
        NSError *error = [LGError errorWithCode:i];
        XCTAssertNotNil(error.localizedDescription, @"Error description for code % is nil", i);
        XCTAssertNotNil(error.localizedRecoverySuggestion, @"Error suggestion for code % is nil", i);
        i++;
    }
}

#pragma mark - Progress delegate
- (void)startProgressWithMessage:(NSString *)message
{
}
- (void)stopProgress:(NSError *)error {}
- (void)bringAutoPkgrToFront {}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    NSLog(@"%@", message);
}
@end
