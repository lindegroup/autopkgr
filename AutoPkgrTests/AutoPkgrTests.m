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

#import <XCTest/XCTest.h>
#import "LGInstaller.h"
#import "LGGitHubJSONLoader.h"
#import "LGAutoPkgr.h"
#import "LGIntegrationManager.h"
#import "LGJSSImporterIntegration.h"
#import "LGJSSDistributionPoint.h"

#import "LGAutoPkgTask.h"
#import "LGAutoPkgReport.h"
#import "LGAutoPkgErrorHandler.h"
#import "LGAutoPkgRecipeListManager.h"

#import "LGPasswords.h"
#import "LGServerCredentials.h"

#import "LGNotificationManager.h"
#import "LGSlackNotification.h"
#import "LGHipChatNotification.h"

#import "LGUserNotification.h"

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
- (void)testDP
{

    LGJSSImporterDefaults *defaults  = [[LGJSSImporterDefaults alloc] init];
    NSArray *arr = [LGJSSDistributionPoint enabledDistributionPoints];

    [arr enumerateObjectsUsingBlock:^(LGJSSDistributionPoint *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj remove];
    }];
    NSLog(@"%@", defaults.JSSRepos);

    [arr enumerateObjectsUsingBlock:^(LGJSSDistributionPoint *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj save];
    }];

    NSLog(@"%@", defaults.JSSRepos);
}

- (void)testSyncMethods
{
    XCTAssertNotNil([LGAutoPkgTask repoList], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask listProcessors], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask listRecipes], @"Failed test");
    XCTAssertNotNil([LGAutoPkgTask processorInfo:@"Installer"], @"Failed test");
}

- (void)testRecipeLists {
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
        } else {
            [expectation2 fulfill];
        };
    }];
    
    [integration refresh];
    [integration install:nil];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
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

    if (_TEST_PRIVILEGED_HELPER){
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
            } reply:^(NSError *error) {
                XCTAssert([NSThread isMainThread], @"Not main thread");
                XCTAssertNil(error, @"error %@", error.localizedDescription);
                [expectations[i] fulfill];
            }];
        }

        [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
            if(error)
            {
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
        if(error)
        {
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
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}



- (void)testVersionCompare {
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

- (void)testCredentials {

    XCTestExpectation *wait = [self expectationWithDescription:@"Web Credential Test"];

    LGJSSImporterDefaults *defaults = [[LGJSSImporterDefaults alloc] init];

    LGHTTPCredential *credentials = [LGHTTPCredential new];
    credentials.server = defaults.JSSURL;
    credentials.user = defaults.JSSAPIUsername;
    credentials.password = defaults.JSSAPIPassword;

    if (credentials.server.length && credentials.user.length && credentials.password.length) {
        [credentials checkCredentialsForPath:@"JSSResource/distributionpoints" reply:^(LGHTTPCredential *cred, LGCredentialChallengeCode status, NSError *error) {
            XCTAssertTrue(status == kLGCredentialChallengeSuccess, @"Authorization check failed: %@", error.localizedDescription);
            [wait fulfill];
        }];
    }
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
        if(error)
        {
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

//- (void)test0_4_3_reportLimited
//{
//    [self runReportTestWithResourceNamed:@"report_0.4.3" flags:kLGReportItemsJSSImports | kLGReportItemsNewInstalls];
//}

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

    if(![d writeToFile:@"/tmp/example_data.plist" atomically:YES]){
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

- (void)testNotificationManager {
    // Set up User Notification Delegate
    _noteDelegate = [[LGUserNotificationsDelegate alloc] initAsDefaultCenterDelegate];
    XCTestExpectation *expectation = [self expectationWithDescription:@"Notification manager test"];

    LGNotificationManager *mgr = [[LGNotificationManager alloc] initWithReportDictionary:[self notificationReport].autoPkgReport
                                                                                  errors:[self reportError]];

    [mgr sendEnabledNotifications:^(NSError *error) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];

}

- (void)testIsNetworkOpCheck {
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
    NSInteger ck = (kLGAutoPkgRepoAdd | kLGAutoPkgRepoUpdate | kLGAutoPkgRun | kLGAutoPkgSearch );

    BOOL isNetworkOperation = verb & ck;

    return isNetworkOperation;
}


- (void)testSlackNotification {
    id<LGNotificationServiceProtocol>notification = [[LGSlackNotification alloc] initWithReport:[self notificationReport]];
    XCTestExpectation *expectation = [self expectationWithDescription:quick_formatString(@"Test %@", [notification.class serviceDescription])];

    [notification send:^(NSError *error) {
        if (_TEST_PRIVILEGED_HELPER) {
            XCTAssertNil(error, @"%@", error);
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        XCTAssertNil(error,@"Expectation Failed with error: %@", error);
    }];
}

- (void)testHipChatNotification {
    id<LGNotificationServiceProtocol>notification = [[LGHipChatNotification alloc] initWithReport:[self notificationReport]];
    
    XCTestExpectation *expectation = [self expectationWithDescription:quick_formatString(@"Test %@", [notification.class serviceDescription])];

    [notification send:^(NSError *error) {
        if (_TEST_PRIVILEGED_HELPER) {
            XCTAssertNil(error, @"%@", error);
        }
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        XCTAssertNil(error,@"Expectation Failed with error: %@", error);
    }];
}

#pragma mark - Utility
- (void)testErrorAlerts {
    for (int i = 1; i < kLGErrorAuthChallenge; i++) {
        NSError *error = [LGError errorWithCode:i];
        XCTAssertNotNil(error.localizedDescription, @"Error description for code % is nil", i);
        XCTAssertNotNil(error.localizedRecoverySuggestion, @"Error suggestion for code % is nil", i);
        i++;
    }
}

#pragma mark - Progress delegate
- (void)startProgressWithMessage:(NSString *)message{}
- (void)stopProgress:(NSError *)error{}
- (void)bringAutoPkgrToFront{}

- (void)updateProgress:(NSString *)message progress:(double)progress{
    NSLog(@"%@", message);
}
@end
