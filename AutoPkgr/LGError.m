//
//  LGError.m
//  AutoPkgr
//
//  Created by Eldon on 8/9/14.
//
//  Copyright 2014 The Linde Group, Inc.
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

#import "LGError.h"
#import "LGConstants.h"
#import <syslog.h>

// Debug Logging Method
void DLog(NSString *format, ...)
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"debug"]) {
        if (format) {
            va_list args;
            va_start(args, format);
            NSLogv([@"[DEBUG] " stringByAppendingString:format], args);
            va_end(args);
        }
    }
}

static NSDictionary *userInfoFromCode(LGErrorCodes code)
{
    NSString *localizedBaseString;
    NSString *message;
    NSString *suggestion;
    switch (code) {
    case kLGErrorSuccess:
        localizedBaseString = @"kLGErrorSuccess";
        break;
    case kLGErrorSendingEmail:
        localizedBaseString = @"kLGErrorSendingEmail";
        break;
    case kLGErrorTestingPort:
        localizedBaseString = @"kLGErrorTestingPort";
        break;
    case kLGErrorReparingAutoPkgPrefs:
        localizedBaseString = @"kLGErrorReparingAutoPkgPrefs";
        break;
    case kLGErrorMultipleRunsOfAutopkg:
        localizedBaseString = @"kLGErrorMultipleRunsOfAutopkg";
        break;
    case kLGErrorInstallGit:
        localizedBaseString = @"kLGErrorInstallGit";
        break;
    case kLGErrorInstallAutoPkg:
        localizedBaseString = @"kLGErrorInstallAutoPkg";
        break;
    case kLGErrorInstallAutoPkgr:
        localizedBaseString = @"kLGErrorInstallAutoPkgr";
        break;
    case kLGErrorInstallJSSAddon:
        localizedBaseString = @"kLGErrorInstallJSSAddon";
        break;
    case kLGErrorJSSXMLSerializerError:
        localizedBaseString = @"kLGErrorJSSXMLSerializerError";
        break;
    default:
        localizedBaseString = @"kLGErrorUnknown";
        break;
    }

    // Setup the localized description
    message = NSLocalizedString([localizedBaseString stringByAppendingString:@"Description"],
                                @"NSLocalizedDescriptionKey");

    // Setup the localized recovery suggestion
    suggestion = NSLocalizedString([localizedBaseString stringByAppendingString:@"Suggestion"],
                                   @"NSLocalizedRecoverySuggestionErrorKey");

    return @{
        NSLocalizedDescriptionKey : message,
        NSLocalizedRecoverySuggestionErrorKey : suggestion,
    };
}

static NSString *errorMessageFromAutoPkgVerb(LGAutoPkgVerb verb)
{
    NSString *localizedBaseString;
    NSString *message;

    switch (verb) {
    case kLGAutoPkgUndefinedVerb:
        localizedBaseString = @"kLGAutoPkgUndefinedVerb";
        break;
    case kLGAutoPkgRun:
        localizedBaseString = @"kLGAutoPkgRun";
        break;
    case kLGAutoPkgRecipeList:
        localizedBaseString = @"kLGAutoPkgRecipeList";
        break;
    case kLGAutoPkgMakeOverride:
        localizedBaseString = @"kLGAutoPkgMakeOverride";
        break;
    case kLGAutoPkgSearch:
        localizedBaseString = @"kLGAutoPkgSearch";
        break;
    case kLGAutoPkgRepoAdd:
        localizedBaseString = @"kLGAutoPkgRepoAdd";
        break;
    case kLGAutoPkgRepoDelete:
        localizedBaseString = @"kLGAutoPkgRepoDelete";
        break;
    case kLGAutoPkgRepoUpdate:
        localizedBaseString = @"kLGAutoPkgRepoUpdate";
        break;
    case kLGAutoPkgRepoList:
        localizedBaseString = @"kLGAutoPkgRepoList";
        break;
    case kLGAutoPkgVersion:
        localizedBaseString = @"kLGAutoPkgVersion";
        break;
    default:
        localizedBaseString = @"kLGAutoPkgUndefinedVerb";
        break;
    }

    message = NSLocalizedString([localizedBaseString stringByAppendingString:@"Description"],
                                @"NSLocalizedDescriptionKey");
    return message;
}

static NSDictionary *userInfoFromHTTPResponse(NSHTTPURLResponse *response)
{
    NSString *localizedBaseString;
    NSString *message;
    NSString *suggestion;

    switch (response.statusCode) {
    case 200:
        // success
        localizedBaseString = @"kLGHTTPErrorSuccess";
        break;
    case 400:
        // Bad Request
        localizedBaseString = @"kLGHTTPErrorBadRequest";
        break;
    case 401:
        // Unauthorized
        localizedBaseString = @"kLGHTTPErrorUnauthorized";
        break;
    case 403:
        // Forbidden
        localizedBaseString = @"kLGHTTPErrorForbidden";
        break;
    case 404:
        // Not Found
        localizedBaseString = @"kLGHTTPErrorNotFound";
        break;
    case 408:
        // Timeout
        localizedBaseString = @"kLGHTTPErrorTimeout";
        break;
    default:
        // General failure
        localizedBaseString = @"kLGHTTPErrorUnknown";
        break;
    }

    // Setup the localized description
    message = NSLocalizedString([localizedBaseString stringByAppendingString:@"Description"],
                                @"NSLocalizedDescriptionKey");

    // Setup the localized recovery suggestion
    suggestion = NSLocalizedString([localizedBaseString stringByAppendingString:@"Suggestion"],
                                   @"NSLocalizedRecoverySuggestionErrorKey");

    return @{
        NSLocalizedDescriptionKey : message,
        NSLocalizedRecoverySuggestionErrorKey : suggestion,
    };
}

@implementation LGError
#ifdef _APPKITDEFINES_H
+ (void)presentErrorWithCode:(LGErrorCodes)code window:(NSWindow *)window delegate:(id)sender didPresentSelector:(SEL)selector
{
    NSError *error;
    [[self class] errorWithCode:code error:&error];
    [NSApp presentError:error
            modalForWindow:NULL
                  delegate:sender
        didPresentSelector:selector
               contextInfo:NULL];
}
#endif

#pragma mark - AutoPkgr Errors
+ (BOOL)errorWithCode:(LGErrorCodes)code error:(NSError *__autoreleasing *)error
{
    NSError *err = [self errorWithCode:code];
    if (error)
        *error = err;
    return (code == kLGErrorSuccess);
}

+ (NSError *)errorWithCode:(LGErrorCodes)code
{
    NSError *error;
    if (code != kLGErrorSuccess) {
        NSDictionary *userInfo = userInfoFromCode(code);
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:code
                                userInfo:userInfo];
        DLog(@"Error [%ld]: %@ \n %@", code, userInfo[NSLocalizedDescriptionKey], userInfo[NSLocalizedRecoverySuggestionErrorKey]);
    }
    return error;
}

#pragma mark - AutoPkg Task Errors

+ (BOOL)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgVerb)verb error:(NSError **)error
{
    NSError *taskError = [self errorWithTaskError:task verb:verb];
    if (error && taskError) {
        *error = taskError;
    }
    // If no error object was created, or the error code is 0 return YES, otherwise NO.
    return taskError ? taskError.code == kLGErrorSuccess : YES;
}

+ (NSError *)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgVerb)verb
{
    // if task is running
    if ([task isRunning]) {
        return nil;
    }

    if (task.terminationReason == NSTaskTerminationReasonUncaughtSignal) {
        DLog(@"AutoPkg run canceled by user.");
        return nil;
    }

    NSError *error;
    NSString *errorMsg = errorMessageFromAutoPkgVerb(verb);
    NSString *errorDetails;
    NSInteger taskError = task.terminationStatus;

    if ([task.standardError isKindOfClass:[NSPipe class]]) {
        NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
        if (errData) {
            errorDetails = [[NSString alloc] initWithData:errData encoding:NSASCIIStringEncoding];
        }
    }

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

        [recombinedErrorDetails appendFormat:@"A Python exception occurred during the execution of autopkg, see the console log for more details.\n\n[ERROR] %@", exceptionDetails];

        errorDetails = [NSString stringWithString:recombinedErrorDetails];

        // Otherwise continue...
    } else {
        // AutoPkg's rc on a failed repo-update / add / delete is 0, but we want it reported back to the UI so set it to -1.
        if (verb == kLGAutoPkgRepoUpdate || verb == kLGAutoPkgRepoDelete || verb == kLGAutoPkgRepoAdd) {
            if (errorDetails && ![errorDetails isEqualToString:@""]) {
                taskError = kLGErrorAutoPkgConfig;
            }
        }
        // autopkg run exits 255 if no recipe specified
        else if (verb == kLGAutoPkgRun && task.terminationStatus == kLGErrorAutoPkgNoRecipes) {
            errorDetails = @"No recipes specified.";
        }
    }

    // A simple "Failed" message isn't very useful so take it out.
    if (errorDetails) {
        errorDetails = [errorDetails stringByReplacingOccurrencesOfString:@"Failed.\n" withString:@""];
    }

    // Otherwise we can just use the termination status
    if (taskError != 0) {
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:taskError
                                userInfo:@{ NSLocalizedDescriptionKey : errorMsg,
                                            NSLocalizedRecoverySuggestionErrorKey : errorDetails ? errorDetails : @"" }];

        // If Debugging is enabled, log the error message
        DLog(@"Error [%ld] %@ \n %@", (long)taskError, errorMsg, errorDetails);
    }
    return error;
}

#pragma mark - NSURLResponse Error

+ (NSError *)errorWithResponse:(NSHTTPURLResponse *)response
{
    NSError *error;
    NSInteger code = response.statusCode;
    if (code >= 400) {
        NSDictionary *userInfo = userInfoFromHTTPResponse(response);
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:response.statusCode
                                userInfo:userInfo];
        DLog(@"Error [%ld]: %@ \n %@", code, userInfo[NSLocalizedDescriptionKey], userInfo[NSLocalizedRecoverySuggestionErrorKey]);
    }
    return error;
}

+ (BOOL)errorWithResponse:(NSHTTPURLResponse *)response error:(NSError *__autoreleasing *)error
{
    NSError *err = [self errorWithResponse:response];
    if (error)
        *error = err;
    return (err.code == kLGErrorSuccess);
}

@end
