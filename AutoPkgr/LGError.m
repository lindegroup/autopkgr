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

// Debug Logging Method
void DLog(NSString *format, ...)
{
#if DEBUG
    if (format) {
        va_list args;
        va_start(args, format);
        NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"%@", str);
    }
#endif
}

static NSString *errorMsgFromCode(LGErrorCodes code)
{
    NSString *msg;
    switch (code) {
    case kLGErrorSendingEmail:
        msg = @"Error sending email";
        break;
    case kLGErrorTestingPort:
        msg = @"Error verifying server and port";
        break;
    case kLGErrorReparingAutoPkgPrefs:
        msg = @"Unable to resolve some issues with the AutoPkg preferences.";
    default:
        break;
    }
    return msg;
}

static NSString *errorMessageFromAutoPkgVerb(LGAutoPkgrVerb verb)
{
    NSString *msg;
    switch (verb) {
    case kLGUnknown:
        msg = @"AutoPkgr encountered an error";
        break;
    case kLGAutoPkgrRun:
        msg = @"Error running recipes";
        break;
    case kLGAutoPkgrRepoUpdate:
        msg = @"Error updating repos";
        break;
    case kLGAutoPkgrRepoAdd:
        msg = @"Error adding selected repo";
        break;
    case kLGAutoPkgrRepoDelete:
        msg = @"Error removing selected repo";
        break;
    case kLGAutoPkgrMakeOverride:
        msg = @"Error creating overrides file";
        break;
    case kLGAutoPkgrInstallAutoPkg:
        msg = @"Error installing git";
        break;
    case kLGAutoPkgrInstallGit:
        msg = @"Error installing/updating AutoPkg";
        break;
    default:
        msg = @"AutoPkgr encountered an error";
        break;
    }
    return msg;
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

+ (BOOL)errorWithCode:(LGErrorCodes)code error:(NSError *__autoreleasing *)error
{
    NSError *err = [self errorWithCode:code];
    if (error)
        *error = err;
    else
        DLog(@"Error: %@", err.localizedDescription);
    return (code == kLGErrorSuccess);
}

+ (NSError *)errorWithCode:(LGErrorCodes)code
{
    NSError *error;
    if (code != kLGErrorSuccess) {
        NSString *errorMsg = errorMsgFromCode(code);
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:code
                                userInfo:@{ NSLocalizedDescriptionKey : errorMsg }];
        DLog(@"Error [%d] %@ \n %@", code, errorMsg);
    }
    return error;
}

+ (BOOL)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgrVerb)verb error:(NSError **)error
{
    NSError *taskError = [self errorWithTaskError:task verb:verb];
    if (error && taskError) {
        *error = taskError;
    }
    // If no error object was created, or the error code is 0 return YES, otherwise NO.
    return taskError ? taskError.code == kLGErrorSuccess : YES;
}

+ (NSError *)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgrVerb)verb
{
    // if task is running
    if ([task isRunning]) {
        return nil;
    }

    NSError *error;
    NSString *errorMsg = errorMessageFromAutoPkgVerb(verb);
    NSString *errorDetails;
    NSInteger taskError;

    NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];

    errorDetails = [[NSString alloc] initWithData:errData encoding:NSASCIIStringEncoding];
    taskError = task.terminationStatus;
    DLog(@"%ld : %@", task.terminationStatus, errorDetails);

    // AutoPkg's rc on a failed repo-update / delete is 0, so check the stderr for "ERROR" string
    if (verb == kLGAutoPkgrRepoUpdate || verb == kLGAutoPkgrRepoDelete) {
        if ([errorDetails rangeOfString:@"ERROR"].location != NSNotFound) {
            taskError = kLGErrorAutoPkgConfig;
        }
    }
    // autopkg run exits 255 if no recipe speciifed
    else if (verb == kLGAutoPkgrRun && task.terminationStatus == kLGErrorAutoPkgNoRecipes) {
        errorDetails = @"No recipes specified.";
    }

    // Otherwise we can just use the termination status
    if (taskError != 0) {
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:taskError
                                userInfo:@{ NSLocalizedDescriptionKey : errorMsg,
                                            NSLocalizedRecoverySuggestionErrorKey : errorDetails ? errorDetails : @"" }];

        // If Debugging is enabled, log the error message
        DLog(@"Error [%d ] %@ \n %@", taskError, errorMsg, errorDetails);
    }
    return error;
}
@end
