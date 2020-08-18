//
//  LGSimpleMDMIntegration.m
//  AutoPkgr
//
//  Copyright 2020 Shawn Honsberger
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

#import "LGSimpleMDMIntegration.h"

@implementation LGSimpleMDMIntegration

+ (NSString *)name
{
    return @"SimpleMDM Plugin";
}

+ (NSString *)credits
{
    return @"Taylor Boyko\nhttps://github.com/SimpleMDM/munki-plugin";
}

+ (NSArray *)components
{
    return nil;
}

+ (NSString *)defaultRepository
{
    return @"https://github.com/SimpleMDM/munki-plugin.git";
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (NSString *)summaryResultKey
{
    return @"simplmdm_summary_result";
}

@end

@implementation LGSimpleMDMDefaults

// SIMPLEMDM_API_KEY

- (NSString*)runAsCommand {
    NSPipe* pipe = [NSPipe pipe];

    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/bash"];
    [task setArguments:@[@"-c", [NSString stringWithFormat:@"export SIMPLEMDM_API_KEY=%@", self]]];
    [task setStandardOutput:pipe];

    NSFileHandle* file = [pipe fileHandleForReading];
    [task launch];

    return [[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];
}

- (NSString *)SIMPLEMDM_API_KEY
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(SIMPLEMDM_API_KEY))];
    NSString *output = [NSStringFromSelector(@selector(SIMPLEMDM_API_KEY)) runAsCommand];
    return output;
}

- (void)setSIMPLEMDM_API_KEY:(NSString *)SIMPLEMDM_API_KEY
{
    [self setAutoPkgDomainObject:SIMPLEMDM_API_KEY forKey:NSStringFromSelector(@selector(SIMPLEMDM_API_KEY))];
}

@end
