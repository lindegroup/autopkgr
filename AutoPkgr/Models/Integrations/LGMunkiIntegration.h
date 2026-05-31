//
//  LGMunkiIntegration.h
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
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

#import "LGDefaults.h"
#import "LGIntegration.h"

@interface LGMunkiIntegration : LGIntegration

// Sub-package identifiers used to determine the installed Munki metapackage version.
+ (NSArray *)packageIdentifiers;

// Returns the highest PackageVersion across all Munki sub-package receipts in
// the given directory, or nil if none are present. -installedVersion delegates
// here with /private/var/db/receipts/; the directory is parameterized so tests
// can point it at a temp dir.
+ (NSString *)installedVersionFromReceiptsInDirectory:(NSString *)directory;

@end

// This is also a good place to add custom defaults.
@interface LGDefaults (munki)
@property (copy, nonatomic) NSString *default_catalog;
@property (copy, nonatomic) NSString *editor;
@property (copy, nonatomic) NSString *pkginfo_extension;
@property (copy, nonatomic) NSString *repo_path;
@property (copy, nonatomic) NSString *repo_url;

@end