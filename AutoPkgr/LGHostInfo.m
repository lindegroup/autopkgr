//
//  LGHostInfo.m
//  AutoPkgr
//
//  Created by James Barclay on 6/27/14.
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

#import "LGHostInfo.h"
#import "LGConstants.h"
#import "LGAutoPkgr.h"
#import "LGGitHubJSONLoader.h"
#import "LGAutoPkgrHelperConnection.h"

#import "AHKeychain.h"


@implementation LGHostInfo

+ (NSString *)getUserName
{
    return NSUserName();
}

+ (NSString *)getHostName
{
    return [[NSHost currentHost] name];
}

+ (NSString *)getUserAtHostName
{
    NSString *userAtHostName = [NSString stringWithFormat:@"%@@%@", [self getUserName], [self getHostName]];
    return userAtHostName;
}

+ (NSString *)getAppSupportDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = [paths firstObject];
    NSString *autoPkgrSupportDirectory = [applicationSupportDirectory stringByAppendingString:@"/AutoPkgr"];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    NSError *error;

    if ([fm fileExistsAtPath:autoPkgrSupportDirectory isDirectory:&isDir]) {
        if (!isDir) {
            [fm removeItemAtPath:autoPkgrSupportDirectory error:&error];
            if (error) {
                NSLog(@"%@ is a file, and it cannot be deleted.", autoPkgrSupportDirectory);
                return @"";
            }
            [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
            if (error) {
                NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
                return @"";
            }
        }
    } else {
        [fm createDirectoryAtPath:autoPkgrSupportDirectory withIntermediateDirectories:NO attributes:nil error:&error];
        if (error) {
            NSLog(@"Error when creating directory %@", autoPkgrSupportDirectory);
            return @"";
        }
    }

    return autoPkgrSupportDirectory;
}



+ (NSString *)macSerialNumber
{
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                              IOServiceMatching("IOPlatformExpertDevice"));
    CFStringRef cfSerialNumber = NULL;
    NSString *serialNumber = nil;

    if (platformExpert) {
        cfSerialNumber = IORegistryEntryCreateCFProperty(platformExpert,
                                                         CFSTR(kIOPlatformSerialNumberKey),
                                                         kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
    }

    if (cfSerialNumber) {
        serialNumber = [NSString stringWithString:CFBridgingRelease(cfSerialNumber)];
    }

    return serialNumber;
}

@end
