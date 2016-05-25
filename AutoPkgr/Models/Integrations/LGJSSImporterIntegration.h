//
//  LGJSSImporterIntegration.h
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

#import "LGIntegration.h"
#import "LGDefaults.h"

@class LGHTTPCredential;

@interface LGJSSImporterIntegration : LGIntegration

@end

#pragma mark - LGDefaults extensions for JSSImporter Interface
@interface LGJSSImporterDefaults : LGDefaults

+ (instancetype)standardUserDefaults __attribute__((unavailable("Cannot use the shared object in this subclass.")));

@property (copy, nonatomic) NSString *JSSURL;
@property (copy, nonatomic) NSString *JSSAPIUsername;
@property (copy, nonatomic) NSString *JSSAPIPassword;
@property (copy, nonatomic) NSArray *JSSRepos;
@property (assign, nonatomic) BOOL JSSVerifySSL;

@end

