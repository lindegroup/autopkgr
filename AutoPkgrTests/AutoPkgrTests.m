//
//  AutoPkgrTests.m
//  AutoPkgrTests
//
//  Created by James Barclay on 6/25/14.
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

#import <XCTest/XCTest.h>
#import "LGInstaller.h"
#import "LGGitHubJSONLoader.h"
#import "LGAutoPkgr.h"
#import "LGToolStatus.h"
#import "LGAutoPkgTask.h"

#import "LGAutoPkgReport.h"
#import "LGEmailer.h"
#import "LGPasswords.h"
#import "LGServerCredentials.h"

@interface AutoPkgrTests : XCTestCase <LGProgressDelegate>

@end

@implementation AutoPkgrTests

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

#pragma mark - LGTools
- (void)testTools
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Tools Test"];

    LGToolStatus *tool = [LGToolStatus new];
    [tool allToolsStatus:^(NSArray *tools) {
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark - Installers
- (void)testInstallGit
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Git Install Async"];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;

   [installer runInstallerFor:@"Git" githubAPI:kLGGitReleasesJSONURL reply:^(NSError *error) {
       XCTAssertNil(error, @"%@", error.localizedDescription);
       [expectation fulfill];
   }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testInstallAutoPkg
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"AutoPkg Install Async"];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.progressDelegate = self;

    [installer runInstallerFor:@"AutoPkg" githubAPI:kLGAutoPkgReleasesJSONURL reply:^(NSError *error) {
        XCTAssertNil(error, @"%@", error.localizedDescription);
        [expectation fulfill];
    }];


    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testInstallJSSImporter
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"JSSImporter Install Async"];

    LGInstaller *installer = [[LGInstaller alloc] init];
//    installer.progressDelegate = self;

    [installer runInstallerFor:@"JSSImporter" githubAPI:kLGJSSImporterJSONURL reply:^(NSError *error) {
        XCTAssertNil(error, @"%@", error.localizedDescription);
        [expectation fulfill];
    }];

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
    XCTestExpectation *expectation = [self expectationWithDescription:@"Github Release Async"];

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

- (void)testToolAndInstall
{
    XCTestExpectation *expectation1 = [self expectationWithDescription:@"Tool Test"];

    XCTestExpectation *expectation2 = [self expectationWithDescription:@"Tool Install Async"];

    __block BOOL fufillExpectation1 = NO;
    __block LGAutoPkgTool *tool = [[LGAutoPkgTool alloc] init];

    [tool getInfo:^(LGToolInfo *info) {
        XCTAssert(info.remoteVersion, @"Could not get remote version");
        XCTAssert(info.installedVersion, @"Could not get installed version");

        if (!fufillExpectation1) {
            [expectation1 fulfill];
            fufillExpectation1 = YES;
        } else {
            [expectation2 fulfill];
        };
    }];

    [tool install:nil];

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

    LGHTTPCredential *credentials = [LGHTTPCredential new];
    credentials.server = @"https://myjss.jamfcloud.com";
    credentials.user = @"jssTest";
    credentials.password = @"mypassword";

    [credentials checkCredentialsForPath:@"JSSResource/distributionpoints" reply:^(LGHTTPCredential *cred, LGCredentialChallengeCode status, NSError *error) {
        XCTAssertTrue(status == kLGCredentialChallengeSuccess, @"Authorization check failed: %@", error.localizedDescription);
        [wait fulfill];
    }];


    XCTestExpectation *wait2 = [self expectationWithDescription:@"NetMount Credential Test"];

    LGNetMountCredential *netCredential = [LGNetMountCredential new];
    netCredential.server = @"afp://test.server.local/";
    netCredential.user = @"myusername";
    netCredential.password = @"mypassword";

    [netCredential checkCredentialsForShare:@"JSS REPO" reply:^(LGNetMountCredential *cred,LGCredentialChallengeCode code, NSError *error) {
        XCTAssertTrue(code == kLGCredentialChallengeSuccess, @"Authorization check failed: %@", error.localizedDescription );
        [wait2 fulfill];
    }];

    [self waitForExpectationsWithTimeout:60 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testToolAndInstallWithBlock
{

    XCTestExpectation *autoPkgExpectation = [self expectationWithDescription:@"AutoPkg Tool Test"];
    XCTestExpectation *jssImporterExpectation = [self expectationWithDescription:@"JSS Tool Test"];
    XCTestExpectation *gitExpectation = [self expectationWithDescription:@"Git Tool Test"];

    LGAutoPkgTool *apkg = [LGAutoPkgTool new];
    [apkg install:^(NSString *message, double progress) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
    } reply:^(NSError *error) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
        XCTAssertNil(error, @"Not main thread");
        [autoPkgExpectation fulfill];
    }];

    LGJSSImporterTool *jss = [LGJSSImporterTool new];
    [jss install:^(NSString *message, double progress) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
    } reply:^(NSError *error) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
        XCTAssertNil(error, @"Not main thread");
        [jssImporterExpectation fulfill];
    }];

    LGGitTool *git = [LGGitTool new];
    [git install:^(NSString *message, double progress) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
    } reply:^(NSError *error) {
        XCTAssert([NSThread isMainThread], @"Not main thread");
        XCTAssertNil(error, @"Not main thread");
        [gitExpectation fulfill];
    }];


    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

- (void)testTool2
{
    LGAutoPkgTool *tool = [[LGAutoPkgTool alloc] init];
    NSLog(@"%@", tool.info.remoteVersion);
}

- (void)testTool3
{
    LGAutoPkgTool *tool = [[LGAutoPkgTool alloc] init];
    [tool refresh];
    NSLog(@"%@", tool.info.remoteVersion);
}

- (void)testLoader
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Github Release Async"];

    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] initWithGitHubURL:kLGAutoPkgReleasesJSONURL];
    [loader getReleaseInfo:^(LGGitHubReleaseInfo *info, NSError *error) {
        NSLog(@"%@", info.latestVersion);
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
    LGGitHubReleaseInfo *info = [[LGGitHubReleaseInfo alloc] initWithURL:kLGAutoPkgReleasesJSONURL];
    NSLog(@"%@", info.latestVersion);
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

- (void)test0_4_3_reportLimited
{
    [self runReportTestWithResourceNamed:@"report_0.4.3" flags:kLGReportItemsJSSImports | kLGReportItemsNewInstalls];
}

- (void)test_report_none
{
    [self runReportTestWithResourceNamed:@"report_none" flags:kLGReportItemsAll];
}

- (void)test_report_malformed
{
    [self runReportTestWithResourceNamed:@"report_malformed" flags:kLGReportItemsAll];
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

    NSError *error = nil;
    //    error = [NSError errorWithDomain:@"AutoPkgr"
    //                                code:1
    //                            userInfo:@{ NSLocalizedDescriptionKey : @"Error running recipes",
    //                                        NSLocalizedRecoverySuggestionErrorKey : @"Code signature verification failed. Note that all verifications can be disabled by setting the variable DISABLE_CODE_SIGNATURE_VERIFICATION to a non-empty value.\nThere was an unknown exception which causes autopkg to fail." }];

    LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:dict];
    report.error = error;

    report.reportedItemFlags = flags;

    [report.emailMessageString writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];

    [[NSWorkspace sharedWorkspace] openFile:htmlFile];
}

- (void)testReportEmail
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Report Format"];

    [[[LGToolStatus alloc] init] allToolsStatus:^(NSArray *tools) {
        NSString *htmlFile = @"/tmp/report.html";
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        
        NSString *reportFile = [bundle pathForResource:@"report_0.4.2" ofType:@"plist"];
//        NSString *reportFile = [bundle pathForResource:@"report_0.4.3" ofType:@"plist"];

        NSDictionary *reportDict = [NSDictionary dictionaryWithContentsOfFile:reportFile];

        NSError *error = [NSError errorWithDomain:@"AutoPkgr" code:1 userInfo:@{ NSLocalizedDescriptionKey : @"Error running recipes",
                                                                                 NSLocalizedRecoverySuggestionErrorKey : @"Code signature verification failed. Note that all verifications can be disabled by setting the variable DISABLE_CODE_SIGNATURE_VERIFICATION to a non-empty value.\nThere was an unknown exception which causes autopkg to fail." }];

        LGAutoPkgReport *report = [[LGAutoPkgReport alloc] initWithReportDictionary:reportDict];
        report.error = error;
        report.tools = tools;
        
        report.reportedItemFlags = kLGReportItemsAll;

        [report.emailMessageString writeToFile:htmlFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
        
        [[NSWorkspace sharedWorkspace] openFile:htmlFile];
        [expectation fulfill];
    }];

    [self waitForExpectationsWithTimeout:300 handler:^(NSError *error) {
        if(error)
        {
            XCTFail(@"Expectation Failed with error: %@", error);
        }
    }];
}

#pragma mark - Progress delegate
- (void)startProgressWithMessage:(NSString *)message{}
- (void)stopProgress:(NSError *)error{}
- (void)bringAutoPkgrToFront{}
- (void)updateProgress:(NSString *)message progress:(double)progress{}
@end
