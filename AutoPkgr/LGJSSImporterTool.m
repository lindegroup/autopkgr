// LGJSSImporterTool.m
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

#import "LGJSSImporterTool.h"
#import "LGTool+Private.h"

@implementation LGJSSImporterTool
@synthesize installedVersion = _installedVersion;

#pragma mark - Class overrides
+ (NSString *)name
{
    return @"JSSImporter";
}

+ (LGToolTypeFlags)typeFlags
{
    return kLGToolTypeAutoPkgSharedProcessor | kLGToolTypeInstalledPackage;
}

+ (NSString *)gitHubURL
{
    return @"https://api.github.com/repos/sheagcraig/JSSImporter/releases";
}

+ (NSString *)defaultRepository {
   return @"https://github.com/sheagcraig/jss-recipes.git";
}

+ (NSString *)binary
{
    return @"/Library/AutoPkg/autopkglib/JSSImporter.py";
}

+ (NSArray *)components
{
    return @[ self.binary ];
}

+ (NSString *)packageIdentifier
{
    return @"com.github.sheagcraig.jssimporter";
}

# pragma mark - Instance overrides.
- (NSString *)installedVersion
{
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *jssAddonReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jss-autopkg-addon.plist";

    NSString *jssImporterReceipt = @"/private/var/db/receipts/com.github.sheagcraig.jssimporter.plist";

    if ([[self class] isInstalled]) {
        NSDictionary *receiptDict;
        if ([fm fileExistsAtPath:jssImporterReceipt]) {
            receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssImporterReceipt];
        } else if ([fm fileExistsAtPath:jssAddonReceipt]) {
            receiptDict = [NSDictionary dictionaryWithContentsOfFile:jssAddonReceipt];
        }
        _installedVersion = receiptDict[@"PackageVersion"];
    }
    return _installedVersion;
}

@end
