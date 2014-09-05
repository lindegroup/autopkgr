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
    NSString *msg;
    NSString *suggestion;
    switch (code) {
        case kLGErrorSendingEmail:
            msg = @"Error sending email";
            suggestion = @"Please verify the username, password, server and port are correct";
            break;
        case kLGErrorTestingPort:
            msg = @"Error verifying server and port";
            suggestion = @"Please verify server and port are correct";
            break;
        case kLGErrorReparingAutoPkgPrefs:
            msg = @"Unable to resolve some issues with the AutoPkg preferences.";
            suggestion =@"If the problem persists please inspect the com.github.autopkg manually for incorrect values";
        case kLGErrorInstallGit:
            msg = @"Error installing/updating Git";
            suggestion = @"If the problem persists please try manually downloading and installing Git manually";
            break;
        case kLGErrorInstallAutoPkg:
            msg = @"Error installing AutoPkg";
            suggestion = @"If the problem persists please try manually downloading and installing AutoPkg from it's github release page";
            break;
        case kLGErrorInstallAutoPkgr:
            msg = @"Error updating AutoPkgr";
            suggestion = @"If the problem persists please try manually downloading and installing AutoPkgr from it's github release page";
            break;
        default:
            msg = @"An unknown error occured";
            break;
    }
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:msg forKey:NSLocalizedDescriptionKey];
    [userInfo setObject:suggestion forKey:NSLocalizedRecoverySuggestionErrorKey];
    return [NSDictionary dictionaryWithDictionary:userInfo];
}

static NSString *errorMessageFromAutoPkgVerb(LGAutoPkgVerb verb)
{
    NSString *msg;
    switch (verb) {
        case kLGAutoPkgUndefinedVerb:
            msg = @"AutoPkgr encountered an error";
            break;
        case kLGAutoPkgRun:
            msg = @"Error running recipes";
            break;
        case kLGAutoPkgRepoUpdate:
            msg = @"Error updating repos";
            break;
        case kLGAutoPkgRepoAdd:
            msg = @"Error adding selected repo";
            break;
        case kLGAutoPkgRepoDelete:
            msg = @"Error removing selected repo";
            break;
        case kLGAutoPkgMakeOverride:
            msg = @"Error creating overrides file";
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
        DLog(@"Error [%d] %@ \n %@", code, userInfo[NSLocalizedDescriptionKey]);
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
    
    // AutoPkg's rc on a failed repo-update / delete is 0, so check the stderr for "ERROR" string
    if (verb == kLGAutoPkgRepoUpdate || verb == kLGAutoPkgRepoDelete) {
        if ([errorDetails rangeOfString:@"ERROR"].location != NSNotFound) {
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
