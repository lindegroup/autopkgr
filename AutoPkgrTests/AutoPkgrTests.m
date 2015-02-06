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

- (void)testLatestReleases
{
    LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] init];
    NSArray *array = [loader latestReleaseDownloads:kLGGitReleasesJSONURL];
    NSLog(@"%@", array);
}

@end
