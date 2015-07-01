// LGIntegrationTemplate.m
//
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

#import "LGIntegrationTemplate.h"
#import "LGIntegration+Protocols.h"

// Define the protocols you intend to conform to...
@interface LGIntegrationTemplate () <LGIntegrationPackageInstaller,
                                            LGIntegrationSharedProcessor>
@end

#pragma mark - Integration overrides
@implementation LGIntegrationTemplate

// Since this is defined using a protocol, it needs to be synthesized...
// If not conforming to LGTOOLPackageInstaller remove it.
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Class overrides
+ (NSString *)name // (REQUIRED)
{
    return @"Integration Name";
}

+ (NSString *)shortName
{
    /*If the name of the integration is Longer that 10 characters,
     * put an abberviated name here so the buttons don't overflow */
    return @"IGName";
}

+ (NSString *)credits // (REQUIRED)
{
    return @"Copyright 2014 Your Name\nhttp://www.apache.org/licenses/LICENSE-2.0";
}

+ (NSURL *)homePage // (REQUIRED)
{
    return [NSURL URLWithString:@"https://github.com/project/"];
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/reponame/releases";
}

+ (NSString *)defaultRepository // (REQUIRED FOR SHARED PROCESSOR)
{
    return @"https://github.com/yourusername/project.git";
}

+ (NSArray *)components
{
    // If there's not a binary don't include it here!!
    // Also, if the binary is determined dynamicaly handle
    // nil values if using the literal syntax!!!
    return @[ [self binary],
              @"/path/to/another/file",
    ];
}

+ (NSString *)binary
{
    return @"/path/to/binary/if/there/is/one";
}

+ (NSArray *)packageIdentifiers
{
    return @[ @"com.github.package.identifier" ];
}

#pragma mark - Instance overrides
- (NSString *)installedVersion
{
    // Don't do if(_installedVersion)here because the installedVersion will be different after it's installed or updated.

    return [[self versionTaskWithExec:[[self class] binary] arguments:@[ @"version" ]] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

    // or

    return [NSDictionary dictionaryWithContentsOfFile:@"/path/to/some/plist.plist"][@"version"];
}
@end

#pragma mark - Defaults
@implementation LGDefaults (exampleTool)

- (void)setTheKey:(NSString *)theKey
{
    [self setAutoPkgDomainObject:theKey
                          forKey:NSStringFromSelector(@selector(theKey))];
}

- (NSString *)theKey
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(theKey))];
}

@end
