//
//  LGJamfUploaderIntegration.h
//  AutoPkgr
//
//  Copyright 2022 The Linde Group.
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
#import "LGConstants.h"
#import "LGIntegration+Protocols.h"
#import "LGIntegration.h"

@class LGHTTPCredential;

@interface LGJamfUploaderIntegration : LGIntegration

@end

#pragma mark - LGDefaults extensions for JamfUploader Interface
@interface LGJamfUploaderDefaults : LGDefaults

+ (instancetype)standardUserDefaults __attribute__((unavailable("Cannot use the shared object in this subclass.")));

@property (copy, nonatomic) NSString *JAMFURL;
@property (copy, nonatomic) NSString *JAMFAPIUsername;
@property (copy, nonatomic) NSString *JAMFAPIPassword;
@property (copy, nonatomic) NSArray *JAMFRepos;
@property (assign, nonatomic) BOOL JAMFVerifySSL;

@end
