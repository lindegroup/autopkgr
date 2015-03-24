//  LGAutoPkgReport.h
//
//  AutoPkgr
//
//  Created by Eldon Ahrold on 3/22/15.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "LGAutoPkgReport.h"
#import "LGRecipes.h"
#import "LGTools.h"
#import "LGVersionComparator.h"

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

@implementation LGAutoPkgReport {
    NSDictionary *_reportDictionary;
}

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
            [self toolsUpdateAvailable]);
}

- (NSString *)emailSubjectString
{
    if ([_reportDictionary[kReportKeySummaryResults] count] > 0) {
        return [NSString stringWithFormat:@"[%@] New software available for testing", kLGApplicationName];
    } else if ([_reportDictionary[kReportKeyFailures] count] > 0) {
        return [NSString stringWithFormat:@"[%@] failures occurred while running AutoPkg", kLGApplicationName];
    } else if (self.error) {
        return [NSString stringWithFormat:@"[%@] Error occurred while running AutoPkg", kLGApplicationName];
    } else if (_tools) {
        for (LGTool *tool in _tools) {
            if (tool.status == kLGToolUpdateAvailable) {
                return [NSString stringWithFormat:@"Update to helper components available"];
            }
        }
    }
    return nil;
}

- (NSString *)emailMessageString
{
    NSString *overviewString;
    NSString *detailsString;

    NSString *cssString = [NSString html_cssStringFromResourceNamed:@"report"
                                                             bundle:[NSBundle bundleForClass:[self class]]];

    if (!cssString) {
        // If there's a problem getting the bundle resource revert to the hard coded CSS string.
        cssString = html_reportCSS;
    }

    NSMutableString *message = [cssString mutableCopy];

    if ((overviewString = [self overviewString])) {
        [message appendString:overviewString];
    }

    if ((detailsString = [self detailsString])) {
        [message appendString:html_breakTwice];
        [message appendString:detailsString];
    }

    return [message copy];
}

#pragma mark - Private
- (NSString *)overviewString
{
    NSMutableString *overview = [@"Overview".html_H1 mutableCopy];
    NSInteger initialLength = overview.length;

    NSString *newSoftware;
    NSString *runFailures;
    NSString *errorsString;
    NSString *toolsString;

    if ((newSoftware = [self newSoftwareString])) {
        [overview appendString:newSoftware];
    }

    if ((runFailures = [self runFailuresString])) {
        [overview appendString:runFailures];
    }

    if ((errorsString = [self errorString])) {
        [overview appendString:errorsString];
    }

    if ((toolsString = [self toolsStatusString])) {
        [overview appendString:toolsString];
    }

    if (initialLength == overview.length) {
        [overview appendString:@"Nothing new to report."];
    }

    return [overview copy];
}

- (NSString *)newSoftwareString
{
    NSMutableString *string = nil;

    NSArray *detectedVersions = [_reportDictionary objectForKey:kReportKeyDetectedVersions] ?: @[];

    NSMutableSet *downloadList = [[NSMutableSet alloc] init];
    NSArray *array = _reportDictionary[kReportKeySummaryResults][kReportProcessorURLDownloader][kReportKeyDataRows];

    for (NSDictionary *d in array) {
        NSString *item = d[@"download_path"];
        if (item) {
            [downloadList addObject:[item lastPathComponent]];
        }
    }

    if (downloadList.count) {
        string = [@"New software available for testing".html_strongStyle mutableCopy];
        [string appendString:html_openDivTabbed];

        for (NSString *appPath in downloadList) {
            NSString *version = nil;
            NSString *app = [[appPath lastPathComponent] stringByDeletingPathExtension];

            NSPredicate *versionPredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", @"pkg_path", [app stringByDeletingPathExtension]];
            for (NSDictionary *d in detectedVersions) {
                if ([versionPredicate evaluateWithObject:d] && d[@"version"]) {
                    version = d[@"version"];
                }
            }
            [string appendFormat:@"%@: %@%@", app.html_strongStyle, version.html_italicStyle ?: @"Unknown version.", html_break];
        }
        [string appendString:html_break];
        [string appendString:html_closingDiv];
    }
    return [string copy];
}

- (NSString *)runFailuresString
{
    NSArray *failures = _reportDictionary[kReportKeyFailures];
    NSMutableString *string = nil;

    if (failures.count) {
        string = [@"The following failures occurred.".html_strongStyleWithBreak mutableCopy];
        [string appendString:html_openDivTabbed];
        for (NSDictionary *failure in failures) {
            [string appendString:[failure[@"message"] html_withBreak]];
        }
        [string appendString:html_closingDiv];
        [string appendString:html_break];
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

        string = [@"Details".html_H2 mutableCopy];
        [summaryResults enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *summary, BOOL *stop) {
            // If the included processor is nil show everything.
            if (!includedProcessors || [includedProcessors containsObject:key]) {
                NSArray *headers = summary[kReportKeyHeaders];
                NSArray *data_rows = summary[kReportKeyDataRows];

                [string appendString:[summary[kReportKeySummaryText] html_strongStyleWithBreak]];
                [string appendString:html_openDivTabbed];
                BOOL addFinalBreak = YES;
                for (NSDictionary* row in data_rows) {
                    if (headers.count > 1) {
                        addFinalBreak = NO;
                        for (NSString *key in headers) {
                            if (row[key]) {
                                [string appendFormat:@"%@: %@", key.html_strongStyle, [row[key] html_withBreak]];
                            }
                        }
                        [string appendString:html_break];
                    } else {
                        [row enumerateKeysAndObjectsUsingBlock:^(NSString *d_key, NSString *item, BOOL *stop) {
                            [string appendString: item.html_withBreak];
                        }];
                    }
                }
                [string appendString:html_closingDiv];
                if (addFinalBreak) {
                    [string appendString:html_break];
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

        NSArray *failures = _reportDictionary[kReportKeyFailures];
        NSMutableOrderedSet *set = [NSMutableOrderedSet new];

        for (NSString *errString in recoverySuggestions.removeEmptyStrings) {
            NSPredicate *failurePredicate = [NSPredicate predicateWithFormat:@"message CONTAINS[cd] %@", errString];

            // Look over the failures array, if the same string occurred there
            // Don't bother reporting it a second time here.
            if (![failures filteredArrayUsingPredicate:failurePredicate].count) {
                if (!string) {
                    string = [@"The following errors occurred:".html_strongStyle mutableCopy];
                }
                if ([noValidRecipePredicate evaluateWithObject:errString]) {
                    // Remove Recipe from Recipe.txt
                    [LGRecipes removeRecipeFromRecipeList:[[errString componentsSeparatedByString:noValidRecipe] lastObject]];
                    [set addObject:[errString stringByAppendingString:@". It has been automatically removed from your recipe list in order to prevent recurring errors."]];
                } else {
                    [set addObject:errString];
                }
            }
        }

        if (set.count) {
            [string appendString:[set.array html_list_unordered]];
        }

        [string appendString:html_closingDiv];
    }
    return [string copy];
}

- (NSString *)toolsStatusString
{
    NSMutableString *string = nil;

    for (LGTool *tool in _tools) {
        if (tool.status == kLGToolUpdateAvailable) {
            if (!string) {
                string = [@"Updates for helper tools:".html_strongStyle mutableCopy];
                [string appendString:html_openDivTabbed];
            }
            [string appendString:tool.statusString.html_withBreak];
        }
    }
    if (string) {
        [string appendString:html_closingDiv];
    }

    return [string copy];
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
    if ([LGVersionComparator isVersion:report[@"report_version"] greaterThanVersion:@"0.4.2"]) {
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

- (BOOL)toolsUpdateAvailable
{
    for (LGTool *tool in _tools) {
        if (tool.status == kLGToolUpdateAvailable) {
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
