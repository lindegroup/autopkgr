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
        default:
            localizedBaseString = @"kLGErrorUnknown";
            break;
    }
    
    // Setup the localized descripton
    message = NSLocalizedString([localizedBaseString stringByAppendingString:@"Description"],
                                @"NSLocalizedDescriptionKey");
    
    // Setup the localized recovery suggestion
    suggestion = NSLocalizedString([localizedBaseString stringByAppendingString:@"Suggestion"],
                                   @"NSLocalizedRecoverySuggestionErrorKey");

    
    return @{NSLocalizedDescriptionKey:message,
              NSLocalizedRecoverySuggestionErrorKey:suggestion,};
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
    if (error)*error = err;
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
        DLog(@"Error [%d]: %@ \n %@", code, userInfo[NSLocalizedDescriptionKey],userInfo[NSLocalizedRecoverySuggestionErrorKey]);
    }
    return error;
}

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
    NSInteger taskError;
    
    if([task.standardError isKindOfClass:[NSPipe class]]){
        NSData *errData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
        if(errData){
            errorDetails = [[NSString alloc] initWithData:errData encoding:NSASCIIStringEncoding];
        }
    }

    taskError = task.terminationStatus;    
    // AutoPkg's rc on a failed repo-update / add / delete is 0, so check the stderr for "ERROR" string
    if (verb == kLGAutoPkgRepoUpdate || verb == kLGAutoPkgRepoDelete || verb == kLGAutoPkgRepoAdd) {
        if (errorDetails && ![errorDetails isEqualToString:@""]) {
            taskError = kLGErrorAutoPkgConfig;
        }
    }
    // autopkg run exits 255 if no recipe speciifed
    else if (verb == kLGAutoPkgRun && task.terminationStatus == kLGErrorAutoPkgNoRecipes) {
        errorDetails = @"No recipes specified.";
    }
    
    // Otherwise we can just use the termination status
    if (taskError != 0) {
        error = [NSError errorWithDomain:kLGApplicationName
                                    code:taskError
                                userInfo:@{ NSLocalizedDescriptionKey : errorMsg,
                                            NSLocalizedRecoverySuggestionErrorKey : errorDetails ? errorDetails : @"" }];
        
        // If Debugging is enabled, log the error message
        DLog(@"Error [%d] %@ \n %@", taskError, errorMsg, errorDetails);
    }
    return error;
}
@end
