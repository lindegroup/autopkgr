//
//  LGMacPatchIntegration.h
//  AutoPkgr
//
//  Copyright 2015 The Linde Group, Inc.
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
#import "LGIntegration+Protocols.h"

@interface LGMacPatchIntegration : LGIntegration<LGIntegrationSharedProcessor>

@end

@interface LGMacPatchDefaults : LGDefaults

@property (copy, nonatomic) NSString *MP_URL;
@property (copy, nonatomic) NSString *MP_USER;
@property (copy, nonatomic) NSString *MP_PASSWORD;
@property (nonatomic) BOOL MP_SSL_VERIFY;

@end