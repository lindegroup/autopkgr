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
#import "LGTools.h"
#import "LGAutoPkgReport.h"
#import "LGEmailer.h"
#import "LGPasswords.h"

@interface AutoPkgrTests : XCTestCase

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
    [installer installGit:^(NSError *error) {
        XCTAssertNil(error, @"Error installing Git: %@",error);
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
    [installer installAutoPkg:^(NSError *error) {
        XCTAssertNil(error, @"Error installing AutoPkgr: %@",error);
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
    [installer installJSSImporter:^(NSError *error) {
        XCTAssertNil(error, @"Error installing JSSImporter: %@",error);
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
    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
    NSArray *array = [loader latestReleaseDownloads:kLGGitReleasesJSONURL];
    NSLog(@"%@", array);
}

#pragma mark - LGAutoPkgReports
- (void)test0_4_2_report
{
    [self runReportTestWithResourceNamed:@"report_0.4.2" flags:kLGReportItemsAll];
}

- (void)test0_4_3_report {
    [self runReportTestWithResourceNamed:@"report_0.4.3" flags:kLGReportItemsAll];
}

- (void)test0_4_3_reportLimited {
    [self runReportTestWithResourceNamed:@"report_0.4.3" flags:kLGReportItemsJSSImports | kLGReportItemsNewInstalls];
}

- (void)test_report_none {
    [self runReportTestWithResourceNamed:@"report_none" flags:kLGReportItemsAll];
}

- (void)test_report_malformed {
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

@end
