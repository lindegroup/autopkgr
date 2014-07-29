//
//  AHLaunchCtlTests.m
//  AHLaunchCtlTests
//
//  Created by Eldon on 2/4/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "AHLaunchCtl.h"
#import <ServiceManagement/ServiceManagement.h>


@interface AHLaunchCtlTests : XCTestCase

@end

@implementation AHLaunchCtlTests

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

- (void)testExample
{
    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

-(void)testAdd
{
    NSError *error;
    AHLaunchJob* job = [AHLaunchJob new];
    job.Program = @"/bin/echo";
    job.Label = @"com.eeaapps.echo.helloworld";
    job.ProgramArguments = @[@"/bin/echo",@"hello world"];
    job.StandardOutPath = @"/tmp/hello.txt";
    job.RunAtLoad = YES;
    [[AHLaunchCtl sharedControler] add:job
                              toDomain:kAHUserLaunchAgent
                                 error:&error];
}


-(void)testLoad
{
    NSError *error;
    AHLaunchJob* job = [AHLaunchJob new];
    job.Program = @"/bin/echo";
    job.Label = @"com.eeaapps.echo.helloworld";
    job.ProgramArguments = @[@"/bin/echo",@"hello world"];
    job.StandardOutPath = @"/tmp/hello.txt";
    
    [[AHLaunchCtl sharedControler] load:job
                               inDomain:kAHGlobalLaunchDaemon
                                  error:&error];
}

-(void)testUnload
{
    NSError *error;

[[AHLaunchCtl sharedControler]unload:@"com.eeaapps.echo.helloworld"
                            inDomain:kAHGlobalLaunchDaemon
                               error:&error];
}
-(void)testRemove
{
    NSError* error;
    XCTAssertTrue([[AHLaunchCtl sharedControler] remove:@"com.eeaapps.echo.helloworld"
                                             fromDomain:kAHUserLaunchAgent
                                                  error:&error], @"Error: %@",error.localizedDescription);
}

-(void)testGetJob{
    AHLaunchJob *job = [AHLaunchCtl runningJobWithLabel:@"com.eeaapps.echo.helloworld"
                                               inDomain:kAHUserLaunchAgent ];
    NSLog(@"%@",job);
    
}

-(void)testRestart{
    NSError* error;
    XCTAssertTrue([[AHLaunchCtl sharedControler] start:@"com.eeaapps.echo.helloworld"
                                              inDomain:kAHUserLaunchAgent
                                                 error:&error], @"Error: %@",error.localizedDescription);
    
    XCTAssertTrue([[AHLaunchCtl sharedControler] restart:@"com.eeaapps.echo.helloworld"
                                          inDomain:kAHUserLaunchAgent
                                             error:&error],
                  @"Error: %@",error.localizedDescription);
}
@end
