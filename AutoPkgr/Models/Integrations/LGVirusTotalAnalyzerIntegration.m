//
//  LGVirusTotalAnalyzerIntegration.m
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

#import "LGVirusTotalAnalyzerIntegration.h"

@implementation LGVirusTotalAnalyzerIntegration

+ (NSString *)name
{
    return @"VirusTotalAnalyzer";
}

+ (NSString *)credits
{
    return @"Copyright 2016 Hannes Juutilainen\nApache License Version 2.0";
}

+ (NSArray *)components
{
    return nil;
}

+ (NSString *)defaultRepository
{
    return @"https://github.com/hjuutilainen/autopkg-virustotalanalyzer.git";
}

+ (NSURL *)homePage
{
    return [NSURL URLWithString:@"https://github.com/hjuutilainen/autopkg-virustotalanalyzer"];
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (NSString *)summaryResultKey
{
    return @"virus_total_analyzer_summary_result";
}

/**
 *  Any custom install actions that need to be taken.
 */
- (void)customInstallActions:(void (^)(NSError *error))reply
{

    LGDefaults *defaults = [[LGDefaults alloc] init];
    NSMutableSet *postProcessors = [[defaults objectForKey:@"PostProcessors"] mutableCopy] ?: [NSMutableSet new];

    [postProcessors addObject:@"io.github.hjuutilainen.VirusTotalAnalyzer/VirusTotalAnalyzer"];

    [defaults setObject:[postProcessors allObjects] forKey:@"PostProcessors"];

    reply(nil);
}

- (void)customUninstallActions:(void (^)(NSError *))reply
{
    LGVirusTotalAnalyzerDefaults *defaults = [LGVirusTotalAnalyzerDefaults new];
    // Set VirusTotalAnalyzer preferences back to their default settings.
    // TODO: Better to remove these entirely (set to nil) but Elliot doesn't yet know how.
    defaults.VIRUSTOTAL_API_KEY = nil;
    defaults.VIRUSTOTAL_ALWAYS_REPORT = NO;
    defaults.VIRUSTOTAL_AUTO_SUBMIT = NO;
    defaults.VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE = 419430400;
    defaults.VIRUSTOTAL_SLEEP_SECONDS = 15;

    NSMutableArray *postProcessors = [[defaults objectForKey:@"PostProcessors"] mutableCopy];
    [postProcessors removeObject:@"io.github.hjuutilainen.VirusTotalAnalyzer/VirusTotalAnalyzer"];
    [defaults setObject:postProcessors forKey:@"PostProcessors"];

    reply(nil);
}

@end

@implementation LGVirusTotalAnalyzerDefaults

// VIRUSTOTAL_API_KEY

- (NSString *)VIRUSTOTAL_API_KEY
{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(VIRUSTOTAL_API_KEY))];
}

- (void)setVIRUSTOTAL_API_KEY:(NSString *)VIRUSTOTAL_API_KEY
{
    [self setAutoPkgDomainObject:VIRUSTOTAL_API_KEY forKey:NSStringFromSelector(@selector(VIRUSTOTAL_API_KEY))];
}

// VIRUSTOTAL_ALWAYS_REPORT

- (BOOL)VIRUSTOTAL_ALWAYS_REPORT
{
    return [[self autoPkgDomainObject:NSStringFromSelector(@selector(VIRUSTOTAL_ALWAYS_REPORT))] boolValue];
}

- (void)setVIRUSTOTAL_ALWAYS_REPORT:(BOOL)VIRUSTOTAL_ALWAYS_REPORT
{
    [self setAutoPkgDomainObject:@(VIRUSTOTAL_ALWAYS_REPORT) forKey:NSStringFromSelector(@selector(VIRUSTOTAL_ALWAYS_REPORT))];
}

// VIRUSTOTAL_AUTO_SUBMIT

- (BOOL)VIRUSTOTAL_AUTO_SUBMIT
{
    return [[self autoPkgDomainObject:NSStringFromSelector(@selector(VIRUSTOTAL_AUTO_SUBMIT))] boolValue];
}

- (void)setVIRUSTOTAL_AUTO_SUBMIT:(BOOL)VIRUSTOTAL_AUTO_SUBMIT
{
    [self setAutoPkgDomainObject:@(VIRUSTOTAL_AUTO_SUBMIT) forKey:NSStringFromSelector(@selector(VIRUSTOTAL_AUTO_SUBMIT))];
}

// VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE

- (NSInteger)VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE
{
    return [[self autoPkgDomainObject:NSStringFromSelector(@selector(VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE))] integerValue];
}

- (void)setVIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE:(NSInteger)VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE
{
    [self setAutoPkgDomainObject:@(VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE) forKey:NSStringFromSelector(@selector(VIRUSTOTAL_AUTO_SUBMIT_MAX_SIZE))];
}

// VIRUSTOTAL_SLEEP_SECONDS

- (NSInteger)VIRUSTOTAL_SLEEP_SECONDS
{
    return [[self autoPkgDomainObject:NSStringFromSelector(@selector(VIRUSTOTAL_SLEEP_SECONDS))] integerValue];
}

- (void)setVIRUSTOTAL_SLEEP_SECONDS:(NSInteger)VIRUSTOTAL_SLEEP_SECONDS
{
    [self setAutoPkgDomainObject:@(VIRUSTOTAL_SLEEP_SECONDS) forKey:NSStringFromSelector(@selector(VIRUSTOTAL_SLEEP_SECONDS))];
}

@end
