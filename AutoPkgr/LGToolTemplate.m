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

#import "LGToolTemplate.h"
#import "LGTool+Private.h"

@implementation LGToolTemplate

- (NSString *)name
{
    return @"ToolName";
}

- (LGToolTypeFlags)typeFlags
{
    return kLGToolTypeInstalledPackage | kLGToolTypeAutoPkgSharedProcessor;
}

- (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/reponame/releases";
}

- (NSString *)defaultRepository {
    return @"https://github.com/sheagcraig/jss-recipes.git";
}

- (NSArray *)components
{
    // If there's not a binary don't include it here!!
    return @[ [self binary],
              @"/path/to/another/file",
              ];
}

- (NSString *)binary
{
    return @"/path/to/binary/if/there/is/one";
}

- (NSString *)packageIdentifier
{
    return @"com.github.package.identifier";
}

- (NSString *)installedVersion
{
    // Don't do if(_installedVersion)here because the installedVersion will be different after it's installed or updated.

    return [[self versionTaskWithExec:self.binary arguments:@[ @"version" ]] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // or

    return [NSDictionary dictionaryWithContentsOfFile:@"/path/to/some/plist.plist"][@"version"];
}

@end
