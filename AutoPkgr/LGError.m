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

static NSString *const kLGLocalizableErrorTable = @"LocalizableError";

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
    case kLGErrorMissingParentRecipe:
        localizedBaseString = @"kLGErrorMissingParentRecipe";
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
    case kLGErrorInstallJSSImporter:
        localizedBaseString = @"kLGErrorInstallJSSImporter";
        break;
    case kLGErrorInstallingGeneric:
        localizedBaseString = @"kLGErrorInstallingGeneric";
        break;
    case kLGErrorJSSXMLSerializerError:
        localizedBaseString = @"kLGErrorJSSXMLSerializerError";
        break;
    case kLGErrorIncorrectScheduleTimerInterval:
        localizedBaseString = @"kLGErrorIncorrectScheduleTimerInterval";
        break;
    case kLGErrorAuthChallenge:
        localizedBaseString = @"kLGErrorAuthChallenge";
        break;
    default:
        localizedBaseString = @"kLGErrorUnknown";
        break;
    }

    // Setup the localized description
    message = NSLocalizedStringFromTable([localizedBaseString stringByAppendingString:@"Description"],
                                         kLGLocalizableErrorTable,
                                         @"NSLocalizedDescriptionKey");

    // Setup the localized recovery suggestion
    suggestion = NSLocalizedStringFromTable([localizedBaseString stringByAppendingString:@"Suggestion"],
                                            kLGLocalizableErrorTable,
                                            @"NSLocalizedRecoverySuggestionErrorKey");

    return @{
        NSLocalizedDescriptionKey : message,
        NSLocalizedRecoverySuggestionErrorKey : suggestion,
    };
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
    message = NSLocalizedStringFromTable([localizedBaseString
                                             stringByAppendingString:@"Description"],
                                         kLGLocalizableErrorTable,
                                         @"NSLocalizedDescriptionKey");

    // Setup the localized recovery suggestion
    suggestion = NSLocalizedStringFromTable([localizedBaseString
                                                stringByAppendingString:@"Suggestion"],
                                            kLGLocalizableErrorTable,
                                            @"NSLocalizedRecoverySuggestionErrorKey");

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
    NSString *errorMsg = @"An error occurred.";

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
