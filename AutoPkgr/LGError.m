//
//  LGError.m
//  AutoPkgr
//
//  Created by Eldon on 8/9/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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
#import "LGLogger.h"

static NSDictionary *userInfoFromCode(LGErrorCodes code)
{
    NSString *message;
    NSString *suggestion;
    switch (code) {
    case kLGErrorSuccess:
        message = NSLocalizedStringFromTable(@"kLGErrorSuccessDescription",
                                             @"LocalizableError",
                                             @"Success, no error occurred");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorSuccessSuggestion",
                                                @"LocalizableError",
                                                @"(NSLocalizedRecoverySuggestionErrorKey)");

        break;
    case kLGErrorSendingEmail:
        message = NSLocalizedStringFromTable(@"kLGErrorSendingEmailDescription",
                                             @"LocalizableError",
                                             @"Generic error when sending email");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorSendingEmailSuggestion",
                                                @"LocalizableError",
                                                @"Generic error when sending email. (NSLocalizedRecoverySuggestionErrorKey)");

        break;
    case kLGErrorTestingPort:
        message = NSLocalizedStringFromTable(@"kLGErrorTestingPortDescription",
                                             @"LocalizableError",
                                             @"Generic error during port testing");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorTestingPortSuggestion",
                                                @"LocalizableError",
                                                @"Generic error during port testing (NSLocalizedRecoverySuggestionErrorKey)");

        break;
    case kLGErrorReparingAutoPkgPrefs:
        message = NSLocalizedStringFromTable(@"kLGErrorReparingAutoPkgPrefsDescription",
                                             @"LocalizableError",
                                             @"Error repairing autopkg preferences file.");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorReparingAutoPkgPrefsSuggestion",
                                                @"LocalizableError",
                                                @"Error repairing autopkg preferences file. (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorMultipleRunsOfAutopkg:
        message = NSLocalizedStringFromTable(@"kLGErrorMultipleRunsOfAutopkgDescription",
                                             @"LocalizableError",
                                             @"Error when trying to run multiple instances of AutoPkg");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorMultipleRunsOfAutopkgSuggestion",
                                                @"LocalizableError",
                                                @"Error when trying to run multiple instances of AutoPkg (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorMissingParentRecipe:
        message = NSLocalizedStringFromTable(@"kLGErrorMissingParentRecipeDescription",
                                             @"LocalizableError",
                                             @"Error when recipe is missing parent recipe");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorMissingParentRecipeSuggestion",
                                                @"LocalizableError",
                                                @"Error when recipe is missing parent recipe (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorInstallingGeneric:
        message = NSLocalizedStringFromTable(@"kLGErrorInstallingGenericDescription",
                                             @"LocalizableError",
                                             @"Generic install error description");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorInstallingGenericSuggestion",
                                                @"LocalizableError",
                                                @"Generic install error (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorJSSXMLSerializerError:
        message = NSLocalizedStringFromTable(@"kLGErrorJSSXMLSerializerErrorDescription",
                                             @"LocalizableError",
                                             @"Error serializing JSS response data.");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorJSSXMLSerializerErrorSuggestion",
                                                @"LocalizableError",
                                                @"Error serializing JSS response data. (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorIncorrectScheduleTimerInterval:
        message = NSLocalizedStringFromTable(@"kLGErrorIncorrectScheduleTimerIntervalDescription",
                                             @"LocalizableError",
                                             @"Error when AutoPkgr schedule timer interval is not valid");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorIncorrectScheduleTimerIntervalSuggestion",
                                                @"LocalizableError",
                                                @"Error when AutoPkgr schedule timer interval is not valid (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case kLGErrorAuthChallenge:
        message = NSLocalizedStringFromTable(@"kLGErrorAuthChallengeDescription",
                                             @"LocalizableError",
                                             @"Error when authorization fails");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorAuthChallengeSuggestion",
                                                @"LocalizableError",
                                                @"Error when authorization fails (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    default:
        message = NSLocalizedStringFromTable(@"kLGErrorUnknownDescription",
                                             @"LocalizableError",
                                             @"Unknown error");

        suggestion = NSLocalizedStringFromTable(@"kLGErrorUnknownSuggestion",
                                                @"LocalizableError",
                                                @"Unknown error (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    }

    return @{
        NSLocalizedDescriptionKey : message,
        NSLocalizedRecoverySuggestionErrorKey : suggestion,
    };
}

static NSDictionary *userInfoFromHTTPResponse(NSHTTPURLResponse *response)
{
    NSString *message;
    NSString *suggestion;

    switch (response.statusCode) {
    case 200:
        // success
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorSuccessDescription",
                                             @"LocalizableError",
                                             @"Success");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorSuccessSuggestion",
                                                @"LocalizableError",
                                                @"success (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case 400:
        // Bad Request
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorBadRequestDescription",
                                             @"LocalizableError",
                                             @"Bad Request response 400");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorBadRequestSuggestion",
                                                @"LocalizableError",
                                                @"Bad Request (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case 401:
        // Unauthorized
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorUnauthorizedDescription",
                                             @"LocalizableError",
                                             @"Unauthorized 401");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorUnauthorizedSuggestion",
                                                @"LocalizableError",
                                                @"Unauthorized 401 (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case 403:
        // Forbidden
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorForbiddenDescription",
                                             @"LocalizableError",
                                             @"Forbidden 403");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorForbiddenSuggestion",
                                                @"LocalizableError",
                                                @"Forbidden 403 (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case 404:
        // Not Found
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorNotFoundDescription",
                                             @"LocalizableError",
                                             @"Not Found 404");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorNotFoundSuggestion",
                                                @"LocalizableError",
                                                @"Not Found 404 (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    case 408:
        // Timeout
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorTimeoutDescription",
                                             @"LocalizableError",
                                             @"Time Out 408");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorTimeoutSuggestion",
                                                @"LocalizableError",
                                                @"Time Out 408 (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    default:
        // General failure
        message = NSLocalizedStringFromTable(@"kLGHTTPErrorUnknownDescription",
                                             @"LocalizableError",
                                             @"Unknown");

        // Setup the localized recovery suggestion
        suggestion = NSLocalizedStringFromTable(@"kLGHTTPErrorUnknownSuggestion",
                                                @"LocalizableError",
                                                @"Unknown (NSLocalizedRecoverySuggestionErrorKey)");
        break;
    }

    return @{
        NSLocalizedDescriptionKey : message,
        NSLocalizedRecoverySuggestionErrorKey : suggestion,
    };
}

@implementation LGError
#ifdef _APPKITDEFINES_H
+ (void)presentErrorWithCode:(LGErrorCodes)code
{
    [[self class] presentErrorWithCode:code window:nil];
}

+ (void)presentErrorWithCode:(LGErrorCodes)code window:(NSWindow *)window;
{
    [[self class] presentErrorWithCode:code window:window delegate:NULL didPresentSelector:NULL];
}

+ (void)presentErrorWithCode:(LGErrorCodes)code window:(NSWindow *)window delegate:(id)sender didPresentSelector:(SEL)selector
{
    NSError *error = [[self class] errorWithCode:code];
    [NSApp presentError:error
            modalForWindow:window
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

+ (NSError *)errorFromTask:(NSTask *)task
{
    // if task is running
    if ([task isRunning]) {
        return nil;
    }

    if (task.terminationReason == NSTaskTerminationReasonUncaughtSignal) {
        return nil;
    }

    NSError *error;
    NSString *errorDetails;

    NSInteger taskError = task.terminationStatus;
    NSString *errorMsg = NSLocalizedStringFromTable(@"An error occurred.",
                                                    @"LocalizableError",
                                                    nil);

    if ([task.standardError isKindOfClass:[NSPipe class]]) {
        NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
        if (errData) {
            errorDetails = [[NSString alloc] initWithData:errData encoding:NSASCIIStringEncoding];
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
