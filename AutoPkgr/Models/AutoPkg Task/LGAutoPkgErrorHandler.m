//
//  LGAutoPkgErrorHandler.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 4/23/15.
//  Copyright 2015 Eldon Ahrold.
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

#import "LGAutoPkgErrorHandler.h"
#import "LGLogger.h"

NSString *LGAutoPkgLocalizedString(NSString *key, NSString *comment)
{
    return [[NSBundle mainBundle] localizedStringForKey:key
                                                  value:key
                                                  table:@"LocalizableAutoPkg"];
}

static NSString *errorMessageFromAutoPkgVerb(LGAutoPkgVerb verb)
{
    NSString *message;

    switch (verb) {
    case kLGAutoPkgRun:
        message = NSLocalizedStringFromTable(@"Error running recipes", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgListRecipes:
        message = NSLocalizedStringFromTable(@"Error encountered listing recipes", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgMakeOverride:
        message = NSLocalizedStringFromTable(@"Error creating recipe override file", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgSearch:
        message = NSLocalizedStringFromTable(@"Error encountered searching for recipe", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgRepoAdd:
        message = NSLocalizedStringFromTable(@"Error adding repo", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgRepoDelete:
        message = NSLocalizedStringFromTable(@"Error removing repo", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgRepoUpdate:
        message = NSLocalizedStringFromTable(@"Error updating repo", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgRepoList:
        message = NSLocalizedStringFromTable(@"Error encountered listing repos", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgVersion:
        message = NSLocalizedStringFromTable(@"Error getting AutoPkg version", @"LocalizableAutoPkg", nil);
        break;
    case kLGAutoPkgUndefinedVerb:
    default:
        message = NSLocalizedStringFromTable(@"AutoPkgr encountered an error", @"LocalizableAutoPkg", nil);
        break;
    }

    return message;
}

static NSDictionary *errorFromAutoPkgGitHubAPICode(LGAutoPkgGitHubAPIError code)
{
    NSDictionary *userInfo = nil;
    switch (code) {
    case kLGAutoPkgErrorGHApi2FAAuthRequired: {
        userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"Two factor authentication is required", @"LocalizableAutoPkg", nil),
                      NSLocalizedRecoverySuggestionErrorKey : NSLocalizedStringFromTable(@"Your GitHub account has two factor authentication enabled. If you did not recieve a code on your mobile device, check your account's security settings and confirm the information there is correct.", @"LocalizableAutoPkg", nil) };
        break;
    }
    case kLGAutoPkgErrorAPITokenNotOnRemote: {
        userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"API Token not found.", @"LocalizableAutoPkg", nil),
                      NSLocalizedRecoverySuggestionErrorKey : NSLocalizedStringFromTable(@"A GitHub API token matching the local one was not found on the remote. You may need to remove it manually. If you've just added the token, you may need to wait a minute to delete it.", @"LocalizableAutoPkg", nil) };
    } break;
    default: {
        userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedStringFromTable(@"There was a problem communicating with GitHub", @"LocalizableAutoPkg", nil) };
        break;
    }
    }
    return userInfo;
}

NSString *maskPasswordInString(NSString *string)
{
    NSError *error;
    NSMutableString *retractedString = [string mutableCopy];

    NSString *baseAll = @"a-zA-Z0-9~`!#.,$%^&*()-_{}<>?";
    NSString *pattern = [NSString stringWithFormat:@"([%@]+:[%@]+(?=@))", baseAll, baseAll];

    NSRegularExpression *exp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];

    NSRange range = NSMakeRange(0, string.length);
    NSArray *matches = [exp matchesInString:string options:0 range:range];
    for (NSTextCheckingResult *match in matches) {
        NSString *ms = [string substringWithRange:match.range];
        NSArray *array = [ms componentsSeparatedByString:@":"];

        // Make sure to re-range the retracted string each loop, since it gets modified.
        NSRange r_range = NSMakeRange(0, retractedString.length);
        [retractedString replaceOccurrencesOfString:[array lastObject]
                                         withString:@"*******"
                                            options:NSCaseInsensitiveSearch
                                              range:r_range];
    }

    return [retractedString copy];
}

@implementation LGAutoPkgErrorHandler {
    LGAutoPkgVerb _verb;
    NSMutableOrderedSet *_errorStrings;
    NSPipe *_pipe;
}

- (void)dealloc
{
    _pipe.fileHandleForReading.readabilityHandler = nil;
    _pipe = nil;
}

- (instancetype)initWithVerb:(LGAutoPkgVerb)verb
{
    if (self = [super init]) {
        _verb = verb;

        NSPipe *pipe = [NSPipe pipe];
        _pipe = pipe;

        [pipe.fileHandleForReading setReadabilityHandler:^(NSFileHandle *fh) {
          NSData *data = fh.availableData;
          if (data) {
              NSString *str = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];

              if (!_errorStrings) {
                  _errorStrings = [[NSMutableOrderedSet alloc] init];
              }

              [_errorStrings addObject:str];
          }
        }];
    }
    return self;
}

- (NSPipe *)standardError
{
    return _pipe;
}

- (NSString *)errorString
{
    NSArray *errors = nil;
    NSString *errorString = nil;

    if ((errors = _errorStrings.array)) {
        NSArray *filters = @[ @"not (SELF BEGINSWITH[CD] 'Failed.')" ];

        NSPredicate *predicate = [NSPredicate predicateWithFormat:[filters componentsJoinedByString:@" AND "]];

        errorString = [[_errorStrings.array filteredArrayUsingPredicate:predicate] componentsJoinedByString:@"\n"];
    };
    return errorString;
}

- (NSError *)errorWithExitCode:(NSInteger)exitCode
{
    NSError *error = nil;

    NSString *standardErrString = self.errorString;
    if (standardErrString.length) {
        NSString *errorMsg = errorMessageFromAutoPkgVerb(_verb);
        NSString *errorDetails = maskPasswordInString(standardErrString);

        // If the error message looks like a Python exception log it, but trim it up for UI.
        NSPredicate *exceptionPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS 'Traceback'"];
        if ([exceptionPredicate evaluateWithObject:errorDetails]) {
            NSArray *splitExceptionFromError = [errorDetails componentsSeparatedByString:@"Traceback (most recent call last):"];

            // The exception should in theory always be last.
            NSString *fullExceptionMessage = [splitExceptionFromError lastObject];
            NSLog(@"(FULL AUTOPKG TRACEBACK) %@", fullExceptionMessage);

            NSArray *array = [fullExceptionMessage componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

            NSPredicate *noEmptySpaces = [NSPredicate predicateWithFormat:@"not (SELF == '')"];
            NSString *exceptionDetails = [[array filteredArrayUsingPredicate:noEmptySpaces] lastObject];

            NSMutableString *recombinedErrorDetails = [[NSMutableString alloc] init];
            if (splitExceptionFromError.count > 1) {
                // If something came before, put that information back into the errorDetails.
                [recombinedErrorDetails appendString:[splitExceptionFromError firstObject]];
            }

            NSString *formatString = LGAutoPkgLocalizedString(@"A Python exception occurred during the execution of autopkg, see the system log for more details.\n\n[ERROR] %@", nil);

            [recombinedErrorDetails appendFormat:formatString, exceptionDetails];

            errorDetails = [NSString stringWithString:recombinedErrorDetails];

            // Otherwise continue...
        } else {
            // AutoPkg's rc on a failed repo-update / add / delete is 0, but we want it reported back to the UI so set it to kLGAutoPkgErrorRepoModification.
            if (_verb == kLGAutoPkgRepoUpdate || _verb == kLGAutoPkgRepoDelete || _verb == kLGAutoPkgRepoAdd) {
                if (errorDetails.length) {
                    exitCode = kLGAutoPkgErrorRepoModification;
                }
            }
            // autopkg run exits 255 if no recipe specified
            else if (_verb == kLGAutoPkgRun && exitCode == kLGAutoPkgErrorNoRecipes) {
                errorDetails = LGAutoPkgLocalizedString(@"No recipes specified.", nil);
            }
        }

        // Otherwise we can just use the termination status
        if (exitCode != kLGAutoPkgErrorSuccess) {
            error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] ?: @"autopkg"
                                        code:exitCode
                                    userInfo:@{ NSLocalizedDescriptionKey : errorMsg,
                                                NSLocalizedRecoverySuggestionErrorKey : errorDetails ?: @"" }];

            // If Debugging is enabled, log the error message
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"debug"]) {
                NSLog(@"Error [%ld] %@ \n %@", (long)exitCode, errorMsg, errorDetails);
            }
        }
    }

    return error;
}

+ (NSError *)errorWithGitHubAPIErrorCode:(LGAutoPkgGitHubAPIError)statusCode
{
    NSDictionary *userInfo = errorFromAutoPkgGitHubAPICode(statusCode);
    NSError *error = [NSError errorWithDomain:[[NSBundle mainBundle] bundleIdentifier] ?: @"autopkg"
                                         code:statusCode
                                     userInfo:userInfo];
    return error;
}

@end
