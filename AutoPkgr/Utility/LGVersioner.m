//
//  LGVersioner.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 12/9/14.
//  Copyright 2014-2016 The Linde Group, Inc.
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

#import "LGAutoPkgr.h"
#import "LGVersioner.h"

NSString *const kLGVersionerAppKey = @"pkg_path";
NSString *const kLGVersionerVersionKey = @"version";

@interface LGVersioner ()
@property (strong, nonatomic) NSMutableSet *workingSet;

@property (strong, nonatomic) NSString *currentApplication;
@property (strong, nonatomic) NSString *currentVersion;
@end

@implementation LGVersioner {
    BOOL isNew;
}

- (void)parseString:(NSString *)rawString
{
    for (NSString *string in rawString.split_byLine) {
        // If string begins with "Processing" we've started a new app, so reset the current values.

        NSPredicate *predicate = [NSPredicate
            predicateWithFormat:@"SELF BEGINSWITH 'Processing'"];

        if ([predicate evaluateWithObject:string]) {
            _currentVersion = nil;
            _currentApplication = nil;
            isNew = YES;
        }

        if (isNew) {
            [self evaluateApplication:string];
            [self evaluateVersion:string];
            // If there is a new application detected, check if we've successfully found a version string, and write it to our working array.
            if (_currentVersion && _currentApplication) {
                if (!_workingSet) {
                    _workingSet = [[NSMutableSet alloc] init];
                }

                DLog(@"Found app and version: %@:%@", _currentApplication, _currentVersion);
                [_workingSet addObject:@{ kLGVersionerAppKey : _currentApplication,
                                          kLGVersionerVersionKey : _currentVersion }];
                isNew = NO;
            }
        }
    }
}

- (void)evaluateVersion:(NSString *)rawString
{
    NSError *error;
    NSString *pattern = @"((\\d+)\\.(\\d+)(\\.(\\d+))?(\\.(\\d+))?)(?:(?:-(alpha\\d*|beta\\d*|rc\\d*))?)";

    NSString *string = CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (__bridge CFStringRef)rawString, CFSTR(""), kCFStringEncodingUTF8));

    NSRegularExpression *exp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];

    if (string && !error) {
        NSRange range = NSMakeRange(0, string.length);
        NSArray *matches = [exp matchesInString:string options:0 range:range];
        for (NSTextCheckingResult *match in matches) {
            _currentVersion = [string substringWithRange:match.range];
            break;
        }
    }
}

- (void)evaluateApplication:(NSString *)rawString
{

    NSArray *validPathExtensions = @[ @"dmg", @"zip", @"tar", @"gz" ];
    NSArray *possibleProcessors = @[ @"URLDownloader" ];

    // Construct a predicate string from the above values.
    // This will make it easy to adjust in the future, as more processors are used to retrieve apps.
    NSMutableString *predicateString = [[NSMutableString alloc] initWithString:@"("];
    for (int i = 0; i < validPathExtensions.count; i++) {
        [predicateString appendFormat:@"SELF CONTAINS[CD] '.%@' ", validPathExtensions[i]];
        if (i < validPathExtensions.count - 1) {
            [predicateString appendString:@" OR "];
        }
    }
    [predicateString appendString:@") AND ("];

    for (int i = 0; i < possibleProcessors.count; i++) {
        [predicateString appendFormat:@"SELF CONTAINS[CD] '%@' ", possibleProcessors[i]];
        if (i < possibleProcessors.count - 1) {
            [predicateString appendString:@" OR "];
        }
    }
    [predicateString appendString:@")"];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:[predicateString copy]];

    // Look for .dmg or .zip.
    if ([predicate evaluateWithObject:rawString]) {
        // Split by "/", filter array by .dmg, remove file extension.
        NSArray *splitArray = [rawString componentsSeparatedByString:@"/"];
        for (NSString *cmp in splitArray) {
            if ([validPathExtensions containsObject:cmp.pathExtension]) {
                _currentApplication = [[cmp stringByDeletingPathExtension] trimmed];
            }
        }
    }
}

- (NSArray *)currentResults
{
    return _workingSet.count ? [_workingSet allObjects] : @[];
}

@end
