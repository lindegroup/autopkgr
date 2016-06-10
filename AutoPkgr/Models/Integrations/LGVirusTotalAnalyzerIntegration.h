//
//  LGVirusTotalAnalyzerIntegration.h
//  AutoPkgr
//
//  Copyright 2016 Elliot Jordan
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
#import "LGIntegration+Protocols.h"
#import "LGIntegration.h"

@interface LGVirusTotalAnalyzerIntegration : LGIntegration <LGIntegrationSharedProcessor>

@end

@interface LGVirusTotalAnalyzerDefaults : LGDefaults

@property (copy, nonatomic) NSString *VIRUSTOTAL_API_KEY;
@property (nonatomic) BOOL VIRUSTOTAL_ALWAYS_REPORT;
@property (nonatomic) BOOL VIRUSTOTAL_AUTO_SUBMIT;
@property (nonatomic) NSInteger VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE;
@property (nonatomic) NSInteger VIRUSTOTAL_SLEEP_SECONDS;

@end
