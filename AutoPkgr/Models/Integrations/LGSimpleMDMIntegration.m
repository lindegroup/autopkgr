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

/**
 *  Any custom install actions that need to be taken.
 */
//- (void)customInstallActions:(void (^)(NSError *error))reply
//{

//    LGDefaults *defaults = [[LGDefaults alloc] init];
//    NSMutableSet *postProcessors = [[defaults objectForKey:@"PostProcessors"] mutableCopy] ?: [NSMutableSet new];

//    [postProcessors addObject:@"io.github.hjuutilainen.VirusTotalAnalyzer/VirusTotalAnalyzer"];

//    [defaults setObject:[postProcessors allObjects] forKey:@"PostProcessors"];

//    reply(nil);
//}

//- (void)customUninstallActions:(void (^)(NSError *))reply
//{
//    LGSimpleMDMDefaults *defaults = [LGSimpleMDMDefaults new];
//    // Set SimpleMDM preferences back to their default settings.
//    defaults.SIMPLEMDM_API_KEY = nil;

//    NSMutableArray *postProcessors = [[defaults objectForKey:@"PostProcessors"] mutableCopy];
//    [postProcessors removeObject:@"io.github.hjuutilainen.VirusTotalAnalyzer/VirusTotalAnalyzer"];
//    [defaults setObject:postProcessors forKey:@"PostProcessors"];

//    reply(nil);
//}

@end

@implementation LGSimpleMDMDefaults

// SIMPLEMDM_API_KEY

- (NSString *)SIMPLEMDM_API_KEY
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(SIMPLEMDM_API_KEY))];
}

- (void)setSIMPLEMDM_API_KEY:(NSString *)SIMPLEMDM_API_KEY
{
    [self setAutoPkgDomainObject:SIMPLEMDM_API_KEY forKey:NSStringFromSelector(@selector(SIMPLEMDM_API_KEY))];
}

@end
