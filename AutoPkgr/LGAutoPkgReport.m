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

#import "HTMLCategories.h"

// Key for AutoPkg 0.4.3 report summary
NSString *const kReportKeySummaryResults = @"summary_results";

// Key used to check for AutoPkg version
NSString *const kReportKeyReportVersion = @"report_version";

// Other Top level keys
NSString *const kReportKeyFailures = @"failures";
NSString *const kReportKeyDetectedVersions = @"detected_versions";

// _summary_result level keys for AutoPkg report
NSString *const kReportKeySummaryText = @"summary_text";
NSString *const kReportKeyDataRows = @"data_rows";
NSString *const kReportKeyHeaders = @"header";

// _summary_result processor keys
NSString *const kReportProcessorInstaller = @"installer_summary_result";
NSString *const kReportProcessorURLDownloader = @"url_downloader_summary_result";
NSString *const kReportProcessorInstallFromDMG = @"install_from_dmg_summary_result";
NSString *const kReportProcessorMunkiImporter = @"munki_importer_summary_result";
NSString *const kReportProcessorPKGCreator = @"pkg_creator_summary_result";
NSString *const kReportProcessorJSSImporter = @"jss_importer_summary_result";
NSString *const kReportProcessorPKGCopier = @"pkg_copier_summary_result";

NSString *const fallback_reportCSS = @"<style type='text/css'>*{font-family:'Helvetica Neue',Helvetica,sans-serif;font-size:11pt}a{color:#157463;text-decoration:underline}a:hover{color:#0d332a}h1{background-color:#eaf6f4;color:#157463;font-weight:700;font-size:14pt;margin:30px 0 0;padding:5px;text-transform:uppercase;text-align:center}ul{list-style-type:none;padding:0;margin:0;margin-left:1em}p{padding:5px}td,th{padding:5px 15px;text-align:left}th{background-color:#eaf6f4;color:#157463;font-weight:400;text-transform:uppercase}.status,.pkgname{font-weight:700}.footer{font-size:10pt;text-align:center;margin:30px 0 10px}</style>";

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
@end

@implementation LGAutoPkgReport {
    NSDictionary *_reportDictionary;
}

@synthesize updatedApplications = _updatedApplications;

- (instancetype)initWithReportDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        _reportDictionary = [self normalizedAutoPkgReport:dictionary];
        _autoPkgReport = dictionary;
        _reportedItemFlags = kLGReportItemsNone;

#if DEBUG
        [_reportDictionary writeToFile:@"/tmp/report.plist" atomically:YES];
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
    if (([_reportDictionary[kReportKeySummaryResults][kReportProcessorURLDownloader] count] > 0)) {
        return YES;
    }
    return (([_reportDictionary[kReportKeyFailures] count] > 0) || _error ||
            [self integrationsUpdateAvailable]);
}

- (NSString *)emailSubjectString
{
    if ([_reportDictionary[kReportKeySummaryResults] count] > 0) {
        return quick_formatString(NSLocalizedString(@"New software available for testing", nil));
    } else if ([_reportDictionary[kReportKeyFailures] count] > 0) {
        return quick_formatString(NSLocalizedString(@"Failures occurred while running AutoPkg", nil));
    } else if (self.error) {
        return quick_formatString(NSLocalizedString(@"An error occurred while running AutoPkg", nil));
    } else if (_integrations) {
        for (LGIntegration *integration in _integrations) {
            if (integration.info.status == kLGIntegrationUpdateAvailable) {
                return quick_formatString(NSLocalizedString(@"Update to helper components available", nil));
            }
        }
    }
    return nil;
}

- (NSString *)emailMessageString
{
    NSString *overviewString;
    NSString *detailsString;

    NSMutableString *message = [@"<html>\n<head>\n" mutableCopy];

    NSString *cssString = [NSString html_cssStringFromResourceNamed:@"report"
                                                             bundle:[NSBundle bundleForClass:[self class]]];

    if (!cssString) {
        // If there's a problem getting the bundle resource revert to the hard coded CSS string.
        cssString = fallback_reportCSS;
    }

    [message appendString:cssString];

    [message appendString:@"</head>\n<body>"];

    if ((overviewString = [self overviewString])) {
        [message appendString:overviewString];
    }

    if ((detailsString = [self detailsString])) {
        [message appendString:html_breakTwice];
        [message appendString:detailsString];
    }

    NSString *autoPkgrLink = quick_formatString(NSLocalizedString(@"This report was generated by %@", nil),
                                                [@"AutoPkgr" html_link:@"https://github.com/lindegroup/autopkgr"]);

    [message appendString:[autoPkgrLink html_H4]];

    [message appendString:@"\n</body></html>"];

    return [message copy];
}

#pragma mark - Private
- (NSString *)overviewString
{
    NSMutableString *overview = [[NSMutableString alloc] init];
    NSInteger initialLength = overview.length;

    NSString *newSoftware;
    NSString *runFailures;
    NSString *errorsString;
    NSString *integrationString;

    if ((newSoftware = [self newSoftwareString])) {
        [overview appendString:newSoftware];
    }

    if ((integrationString = [self integrationStatusString])) {
        [overview appendString:integrationString];
    }

    if ((runFailures = [self runFailuresString])) {
        [overview appendString:runFailures];
    }

    if ((errorsString = [self errorString])) {
        [overview appendString:errorsString];
    }

    if (initialLength == overview.length) {
        [overview appendString:NSLocalizedString(@"Nothing new to report.", nil)];
    }

    return [overview copy];
}

- (NSString *)newSoftwareString
{
    NSMutableString *string = nil;

    if (self.updatedApplications.count) {
        NSMutableArray *dictArray = [NSMutableArray new];
        string = [NSLocalizedString(@"New software available for testing", nil).html_H3 mutableCopy];

        for (LGUpdatedApplication *application in _updatedApplications) {
            [dictArray addObject:@{ @"name" : application.name,
                                    @"version" : application.version
            }];
        }

        NSString *table = [dictArray html_tableWithHeaders:@[ @"name", @"version" ] cssClassForColumns:@{ @"name" : @"pkgname" }];
        [string appendString:table];
    }
    return [string copy];
}

- (NSString *)runFailuresString
{
    NSArray *failures = [_reportDictionary[kReportKeyFailures] filtered_ByClass:[NSDictionary class]];
    NSMutableString *string = nil;

    if (failures.count) {
        string = [NSLocalizedString(@"The following failures occurred:", nil).html_H3 mutableCopy];
        [string appendString:[failures html_table]];
    }
    return [string copy];
}

- (NSString *)detailsString
{
    NSMutableString *string = nil;
    NSArray *includedProcessors = [self includedProcessorSummaryResults];

    NSDictionary *summaryResults = _reportDictionary[kReportKeySummaryResults];

    // The includedProcessorSummaryResults method returns nil when intended to show all.
    // It's this way to be future compatible with autopkg processors that do
    // yet exist, or do not currently provide _summary_results
    if ((!includedProcessors || includedProcessors.count) && summaryResults.count) {

        string = [[NSMutableString alloc] init];
        [summaryResults enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *summary, BOOL *stop) {
            // If the included processor is nil show everything.
            if (!includedProcessors || [includedProcessors containsObject:key]) {
                NSArray *headers = summary[kReportKeyHeaders];
                NSArray *data_rows = [summary[kReportKeyDataRows] filtered_ByClass:[NSDictionary class]];
                if (data_rows.count) {
                    [string appendString:[summary[kReportKeySummaryText] html_H3]];
                    if (headers.count > 1) {
                        [string appendString:[data_rows html_tableWithHeaders:headers]];
                    } else {
                        [string appendString:html_openListUL];
                        for (NSDictionary *row in data_rows) {
                            NSString *value = [[row allValues] firstObject];
                            [string appendString:[[value stringByAbbreviatingWithTildeInPath] html_listItem]];
                        }
                        [string appendString:html_closeListUL];
                    }
                }
            }
        }];
    }
    return [string copy];
}

- (NSString *)errorString
{
    NSMutableString *string = nil;
    if (_error) {

        NSArray *recoverySuggestions = [_error.localizedRecoverySuggestion
            componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

        NSString *noValidRecipe = @"No valid recipe found for ";
        NSPredicate *noValidRecipePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH %@", noValidRecipe];

        NSArray *failures = [_reportDictionary[kReportKeyFailures] filtered_ByClass:[NSDictionary class]];
        NSMutableOrderedSet *set = [NSMutableOrderedSet new];

        for (NSString *errString in recoverySuggestions.filtered_noEmptyStrings) {
            NSPredicate *failurePredicate = [NSPredicate predicateWithFormat:@"message CONTAINS[cd] %@", errString];

            // Look over the failures array, if the same string occurred there
            // Don't bother reporting it a second time here.
            if (![failures filteredArrayUsingPredicate:failurePredicate].count) {
                if (!string) {
                    string = [NSLocalizedString(@"The following errors occurred:", nil).html_H3 mutableCopy];
                }

                if ([noValidRecipePredicate evaluateWithObject:errString]) {
                    // Remove Recipe from Recipe.txt
                    [LGAutoPkgRecipe removeRecipeFromRecipeList:[[errString componentsSeparatedByString:noValidRecipe] lastObject]];
                    [set addObject:[errString stringByAppendingString:NSLocalizedString(@". It has been automatically removed from your recipe list in order to prevent recurring errors.", nil)]];
                } else {
                    [set addObject:errString];
                }
            }
        }

        if (set.count) {
            [string appendString:[set.array html_list_unordered]];
        }
    }
    return [string copy];
}

- (NSString *)integrationStatusString
{
    NSMutableString *string = nil;

    for (LGIntegration *integration in _integrations) {
        if ([[integration class] isInstalled] && integration.info.status == kLGIntegrationUpdateAvailable) {
            if (!string) {
                string = [NSLocalizedString(@"Updates for integrated components:", nil).html_H3 mutableCopy];
                [string appendString:html_openListUL];
            }
            [string appendString:integration.info.statusString.html_listItem];
        }
    }
    if (string) {
        [string appendString:html_closeListUL];
    }

    return [string copy];
}

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

        [summaryResults setObject:dict forKey:kReportProcessorMunkiImporter];
    }

    return @{
        kReportKeySummaryResults : [summaryResults copy],
        kReportKeyFailures : report[kReportKeyFailures] ?: @[],
        kReportKeyDetectedVersions : report[kReportKeyDetectedVersions] ?: @[],
        kReportKeyReportVersion : report[kReportKeyReportVersion] ?: @"",
    };
}

- (BOOL)integrationsUpdateAvailable
{
    for (LGIntegration *integration in _integrations) {
        if (integration.info.status == kLGIntegrationUpdateAvailable) {
            return YES;
        }
    }
    return NO;
}

/**
 *  Convert the reportedItemFlags to an array of keys used for strcmp during message generation.
 *
 *  @return array of keys matching the equivalent processor's _summary_results string.
 */
- (NSArray *)includedProcessorSummaryResults
{
    if (_reportedItemFlags == kLGReportItemsNone) {
        _reportedItemFlags = [[LGDefaults standardUserDefaults] reportedItemFlags];
    }

    NSMutableArray *itemArray = [[NSMutableArray alloc] init];

    if (_reportedItemFlags & kLGReportItemsAll) {
        return nil;
    } else {
        if (_reportedItemFlags & kLGReportItemsNewDownloads) {
            [itemArray addObject:kReportProcessorURLDownloader];
        }
        if (_reportedItemFlags & kLGReportItemsNewInstalls) {
            [itemArray addObject:kReportProcessorInstaller];
        }
        if (_reportedItemFlags & kLGReportItemsNewPackages) {
            [itemArray addObject:kReportProcessorPKGCreator];
        }
        if (_reportedItemFlags & kLGReportItemsMunkiImports) {
            [itemArray addObject:kReportProcessorMunkiImporter];
        }
        if (_reportedItemFlags & kLGReportItemsJSSImports) {
            [itemArray addObject:kReportProcessorJSSImporter];
        }
    }
    return [itemArray copy];
}

@end
