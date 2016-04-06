//
//  LGAutoPkgReport.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/22/15.
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

#import "LGAutoPkgReport.h"
#import "LGAutoPkgRecipe.h"
#import "LGIntegrationManager.h"
#import "LGIntegration+Protocols.h"

#import "NSArray+mapped.h"
#import "HTMLCategories.h"
#import <GRMustache/GRMustache.h>

// Key for AutoPkg 0.4.3 report summary
static NSString *const kReportKeySummaryResults = @"summary_results";

// Key used to check for AutoPkg version
static NSString *const kReportKeyReportVersion = @"report_version";

// Other Top level keys
static NSString *const kReportKeyFailures = @"failures";
static NSString *const kReportKeyDetectedVersions = @"detected_versions";

// _summary_result level keys for AutoPkg report
static NSString *const kReportKeySummaryText = @"summary_text";
static NSString *const kReportKeyDataRows = @"data_rows";
static NSString *const kReportKeyHeaders = @"header";

// _summary_result processor keys
static NSString *const kReportProcessorURLDownloader = @"url_downloader_summary_result";
static NSString *const kReportProcessorInstallFromDMG = @"install_from_dmg_summary_result";
static NSString *const kReportProcessorInstaller = @"installer_summary_result";
static NSString *const kReportProcessorPKGCopier = @"pkg_copier_summary_result";
static NSString *const kReportProcessorPKGCreator = @"pkg_creator_summary_result";

#pragma mark - LGUpdatedApplication
@implementation LGUpdatedApplication {
    NSDictionary *_dictionary;
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    NSParameterAssert(dictionary[@"path"]);
    if (self = [super init]) {
        _dictionary = dictionary;
    }
    return self;
}

- (NSString *)name
{
    return self.path.lastPathComponent.stringByDeletingPathExtension;
}

- (NSString *)version
{
    return _dictionary[NSStringFromSelector(_cmd)];
}

- (NSString *)path
{
    return _dictionary[NSStringFromSelector(_cmd)];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{ NSStringFromSelector(@selector(path)): self.path,
              NSStringFromSelector(@selector(name)): self.name,
              NSStringFromSelector(@selector(version)): self.version };
}
@end

@implementation LGAutoPkgReport {
@private
    NSDictionary *_reportDictionary;
    NSArray *_includedProcessorSummaryResults;
    NSNumber * _integrationsUpdatesToReport;
}

@synthesize updatedApplications = _updatedApplications;

- (instancetype)initWithReportDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        [self setAutoPkgReport:dictionary];
        _reportedItemFlags = kLGReportItemsNone;
#if DEBUG
        [_reportDictionary writeToFile:@"/tmp/report.plist"
                            atomically:YES];
#endif
    }
    return self;
}

- (void)setAutoPkgReport:(NSDictionary *)autoPkgReport
{
    _reportDictionary = [self normalizedAutoPkgReport:autoPkgReport];
    _autoPkgReport = autoPkgReport;
}

- (BOOL)updatesToReport
{
    BOOL failureCount = [_reportDictionary[kReportKeyFailures] count];
    BOOL summaryCount = [[self includedProcessorSummaryResults] count];

    if (summaryCount || ((_reportedItemFlags & kLGReportItemsFailures) && failureCount) ||
        ((_reportedItemFlags & kLGReportItemsErrors) && _error) || [self integrationsUpdatesToReport]){
        return YES;
    } else if (_reportedItemFlags == kLGReportItemsAll && (failureCount || summaryCount || _error )) {
        return YES;
    }
    return NO;
}

- (NSString *)reportSubject
{
    NSString *subject = nil;
    if ([_reportDictionary[kReportKeyFailures] count]) {
        subject = NSLocalizedString(@"Failures occurred while running AutoPkg", nil);
    }
    else if (self.error) {
        subject =  NSLocalizedString(@"An error occurred while running AutoPkg", nil);
    }
    else if ([self.updatedApplications count] ||
             [[self includedProcessorSummaryResults] count]) {
        subject = NSLocalizedString(@"New software available for testing", nil);
    }
    else if ([self integrationsUpdatesToReport]) {
        subject = NSLocalizedString(@"Update to helper components available", nil);
    }

    // Construct the full subject string...
    if (subject) {
        return quick_formatString(@"%@ on %@", subject, [NSHost currentHost].localizedName);
    }
    return nil;
}

#pragma mark - Templating
- (NSDictionary *)templateData {
    __block NSMutableDictionary *data = [[NSMutableDictionary alloc ] init];
    NSArray *results = [self includedProcessorSummaryResults];
    data[@"has_summary_results"] = @(results.count);

    if (results.count){
        [[self includedProcessorSummaryResults] enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop) {
            NSString *strippedKey = [key stringByReplacingOccurrencesOfString:@"_summary_result" withString:@""];
            data[strippedKey] = _reportDictionary[kReportKeySummaryResults][key];
        }];
    }

    data[kReportKeyFailures] = _reportDictionary[kReportKeyFailures];
    if (self.error) {
        data[@"error"] = @{@"description": _error.localizedDescription,
                           @"suggestion": _error.localizedRecoverySuggestion
                           };
    }

    if (self.updatedApplications) {
        data[@"updated_applications"] = [_updatedApplications mapObjectsUsingBlock:^id(LGUpdatedApplication *obj, NSUInteger idx) {
            return [obj dictionaryRepresentation];
        }];
    }

    if ([self integrationsUpdatesToReport]){
        data[@"integration_updates"] = [self integrationUpdates];
    }

    [data addEntriesFromDictionary:_reportDictionary];
    return data.copy;
}

- (NSString *)renderWithTemplate:(NSString *)templateString error:(NSError *__autoreleasing *)error{
    GRMustacheTemplate *mTemplate = [GRMustacheTemplate templateFromString:templateString error:error];
    return mTemplate ? [mTemplate renderObject:self.templateData error:error] : nil;
}

- (NSArray<NSString *> *)integrationUpdates {
    return [_integrations mapObjectsUsingBlock:^id(LGIntegration* integration, NSUInteger idx) {
        if ([[integration class] isInstalled] && integration.info.status == kLGIntegrationUpdateAvailable) {
            return integration.info.statusString;
        }
        return nil;
    }];
}

#pragma mark - Additional
- (NSArray *)updatedApplications
{
    if (!_updatedApplications) {
        NSArray *detectedVersions = [_reportDictionary objectForKey:kReportKeyDetectedVersions] ?: @[];
        NSMutableSet *downloadList = [[NSMutableSet alloc] init];

        NSArray *array = _reportDictionary[kReportKeySummaryResults][kReportProcessorURLDownloader][kReportKeyDataRows];

        for (NSDictionary *d in array) {
            NSString *item = d[@"download_path"];
            if (item) {
                [downloadList addObject:[item lastPathComponent]];
            }
        }

        NSMutableArray *dictArray = nil;
        if (downloadList.count) {
            dictArray = [NSMutableArray new];
            for (NSString *appPath in downloadList) {
                NSString *version = nil;
                NSString *app = [[appPath lastPathComponent] stringByDeletingPathExtension];

                NSPredicate *versionPredicate = [NSPredicate predicateWithFormat:@"pkg_path CONTAINS[cd] %@", [app stringByDeletingPathExtension]];
                for (NSDictionary *d in detectedVersions) {
                    if ([versionPredicate evaluateWithObject:d] && d[@"version"]) {
                        version = d[@"version"];
                    }
                }
                NSDictionary *d = @{ @"name" : app,
                                     @"path" : appPath,
                                     @"version" : version ?: @"Unknown version"
                };

                LGUpdatedApplication *updatedApp = [[LGUpdatedApplication alloc] initWithDictionary:d];
                [dictArray addObject:updatedApp];
            }
        }
        _updatedApplications = [NSArray arrayWithArray:dictArray];
    }
    return _updatedApplications;
}

- (NSError *)failureError
{
    NSError *failureError = nil;
    NSArray *failures = [_reportDictionary[kReportKeyFailures] filtered_ByClass:[NSDictionary class]];

    if (failures.count) {
        NSMutableString *string = [[NSMutableString alloc] init];
        for (NSDictionary *failure in failures) {
            [string appendFormat:@"%@\n", failure[@"message"]];
        }

        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"The following failures occurred:", nil),
                                    NSLocalizedRecoverySuggestionErrorKey : string };

        failureError = [NSError errorWithDomain:kLGApplicationName code:1 userInfo:userInfo];
    }
    return failureError;
}

#pragma mark - Utility
/**
 *  Normalize report dictionary from AutoPkgr's implementation of @code autopkg run --report-plist @endcode
 *
 *  @param report original report from AutoPkgr's implementation of
 *
 *  @return A dictionary with a matching structure for any version of autopkg
 */
- (NSDictionary *)normalizedAutoPkgReport:(NSDictionary *)report
{

    // Only normalize report for version pre 0.4.3.
    if ([report[@"report_version"] version_isGreaterThanOrEqualTo:@"0.4.3"]) {
        return report;
    }

    NSMutableDictionary *summaryResults = [[NSMutableDictionary alloc] init];

    // Handle new downloads.
    NSArray *newDownloads = report[@"new_downloads"];
    if (newDownloads.count) {
        NSMutableArray *data_rows = [[NSMutableArray alloc] initWithCapacity:newDownloads.count];
        for (NSString *download in newDownloads) {
            [data_rows addObject:@{ @"download_path" : download }];
        }
        NSDictionary *dict = @{ kReportKeyHeaders : @[ @"download_path" ],
                                kReportKeyDataRows : data_rows,
                                kReportKeySummaryText : @"The following new items were downloaded:" };

        [summaryResults setObject:dict forKey:kReportProcessorURLDownloader];
    }

    // Handle new packages.
    NSArray *newPackages = report[@"new_packages"];
    if (newPackages.count) {
        NSDictionary *dict = @{ kReportKeyHeaders : @[ @"id", @"pkg_path", @"version" ],
                                kReportKeyDataRows : newPackages,
                                kReportKeySummaryText : @"The following packages were built:" };

        [summaryResults setObject:dict forKey:kReportProcessorPKGCreator];
    }

    // Handle new imports.
    NSArray *newImports = report[@"new_imports"];
    if (newImports.count) {
        NSArray *headers = @[ @"name", @"version", @"catalogs", @"pkg_path", @"pkginfo_path" ];

        NSMutableArray *dataRows = [NSMutableArray arrayWithCapacity:newImports.count];
        for (NSDictionary *row in newImports) {
            // Reconstruct the dictionary here because in version pre 0.4.3 the catalogs key was an array.
            NSMutableDictionary *row_data = [[NSMutableDictionary alloc] initWithCapacity:headers.count];
            for (NSString *key in headers) {
                id object = row[key];
                if ([object isKindOfClass:[NSArray class]]) {
                    [row_data setObject:[object componentsJoinedByString:@", "] forKey:key];
                } else {
                    [row_data setObject:object forKey:key];
                }
            }
            [dataRows addObject:row_data];
        }

        NSDictionary *dict = @{ kReportKeyHeaders : headers,
                                kReportKeyDataRows : dataRows,
                                kReportKeySummaryText : @"The following new items were imported into Munki:" };

        [summaryResults setObject:dict forKey:@"munki_importer_summary_result"];
    }

    return @{
        kReportKeySummaryResults : [summaryResults copy],
        kReportKeyFailures : report[kReportKeyFailures] ?: @[],
        kReportKeyDetectedVersions : report[kReportKeyDetectedVersions] ?: @[],
        kReportKeyReportVersion : report[kReportKeyReportVersion] ?: @"",
    };
}

- (BOOL)integrationsUpdatesToReport
{
    if (_integrationsUpdatesToReport) {
        return [_integrationsUpdatesToReport boolValue];
    }

    /* Determine if updates to integrations should be reported. */
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    LGReportItems check = (kLGReportItemsIntegrationUpdates | kLGReportItemsAll);
    if (defaults.reportedItemFlags & check) {
        /* ReportIntegrationFrequency is bound to the defaults controller in the
         * LGScheduleViewController.xib. It's bound to the popup button's selectedTag property. */
        LGReportIntegrationFrequency noteFrequency = [defaults integerForKey:@"ReportIntegrationFrequency"];

        for (LGIntegration *integration in _integrations) {
            if (integration.info.status == kLGIntegrationUpdateAvailable) {
                if (noteFrequency == kLGReportIntegrationFrequencyOncePerVersion) {
                    NSString *reportedVersionKey = quick_formatString(@"ReportSentVersion%@", integration.name.spaces_removed);
                    NSString *lastReportedVersion = [defaults stringForKey:reportedVersionKey];

                    NSString *availableVersion = integration.info.remoteVersion;

                    if ([availableVersion version_isGreaterThan:lastReportedVersion]) {
                        [defaults setObject:availableVersion forKey:reportedVersionKey];

                        _integrationsUpdatesToReport = @(YES);
                        return YES;
                    }
                } else {
                    // For all other types, the frequency is a date comparison.
                    NSDate *now = [NSDate date];
                    NSDate *compareDate = nil;

                    switch (noteFrequency) {
                        case kLGReportIntegrationFrequencyDaily: {
                            // 60 Sec * 60 Min * 24Hr = 86400
                            compareDate = [now dateByAddingTimeInterval:-86400];
                            break;
                        }
                        case kLGReportIntegrationFrequencyWeekly:
                        default: {
                            // 60 Sec * 60 Min * 24 Hr * 7 Day = 604800
                            compareDate = [now dateByAddingTimeInterval:-604800];
                            break;
                        }
                    }

                    NSString *reportedDateSentKey = quick_formatString(@"ReportSentDate%@", integration.name.spaces_removed);
                    NSDate *lastReportDate = [defaults objectForKey:reportedDateSentKey];

                    NSComparisonResult comp = [compareDate compare:lastReportDate];
                    if (comp != NSOrderedAscending) {
                        [defaults setObject:now forKey:reportedDateSentKey];

                        _integrationsUpdatesToReport = @(YES);
                        return YES;
                    }
                }
            }
        }
    }
    _integrationsUpdatesToReport = @(NO);
    return NO;
}

/**
 *  Convert the reportedItemFlags to an array of keys used for strcmp during message generation.
 *
 *  @return array of keys matching the equivalent processor's _summary_results string.
 */
- (NSArray *)includedProcessorSummaryResults
{
    if (_includedProcessorSummaryResults){
        return _includedProcessorSummaryResults;
    }

    if (_reportedItemFlags == kLGReportItemsNone) {
        _reportedItemFlags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    }

    NSMutableArray *itemArray = [[NSMutableArray alloc] init];
    [_reportDictionary[kReportKeySummaryResults] enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if (_reportedItemFlags == kLGReportItemsAll) {
            [itemArray addObject:key];
        } else {
            if ([key isEqualToString:kReportProcessorInstaller] ||
                [key isEqualToString:kReportProcessorInstallFromDMG]){
                if(_reportedItemFlags & kLGReportItemsNewInstalls) {
                    [itemArray addObject:key];
                }
            }
            else if([key isEqualToString:kReportProcessorPKGCreator]){
                if(_reportedItemFlags & kLGReportItemsNewPackages) {
                    [itemArray addObject:key];
                }
            }
            else if ([key isEqualToString:kReportProcessorURLDownloader]){
                if(_reportedItemFlags & kLGReportItemsNewDownloads) {
                    [itemArray addObject:key];
                }
            }
        }
    }];

    if ((_reportedItemFlags & kLGReportItemsIntegrationImports) || [self integrationsUpdatesToReport]) {
        [self.integrations enumerateObjectsUsingBlock:^(LGIntegration *obj, NSUInteger idx, BOOL *stop) {
            if ([[obj class] respondsToSelector:@selector(summaryResultKey)]) {
                id key = [[obj class] summaryResultKey];
                if([_reportDictionary[kReportKeySummaryResults][key] count]){
                    [itemArray addObject:key];
                }
            }
        }];
    }
    _includedProcessorSummaryResults = [itemArray copy];
    return _includedProcessorSummaryResults;
}

@end
