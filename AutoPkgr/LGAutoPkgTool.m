// LGAutoPkgTool.m
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGAutoPkgTool.h"
#import "LGTool+Private.h"

@implementation LGAutoPkgTool

- (NSString *)name
{
    return @"AutoPkg";
}

- (LGToolTypeFlags)typeFlags
{
    return kLGToolTypeInstalledPackage | kLGToolTypeAutoPkgSharedProcessor;
}

- (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/autopkg/autopkg/releases";
}

- (NSString *)defaultRepository
{
    return @"https://github.com/autopkg/recipes.git";
}

- (NSArray *)components
{
    return @[ self.binary ];
}

- (NSString *)binary
{
    return @"/usr/local/bin/autopkg";
}

- (NSString *)packageIdentifier
{
    return @"com.github.autopkg.autopkg";
}

- (NSString *)installedVersion
{
    return [[self versionTaskWithExec:self.binary arguments:@[ @"version" ]] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

@end
