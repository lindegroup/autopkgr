//
//  LGError.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/9/14.
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

#import <Foundation/Foundation.h>

// Exception Raise when subclass is required to implement a method.
void subclassMustImplement(id sender, SEL _cmd);

#pragma mark - AutoPkgr specific Error codes
typedef NS_ENUM(NSInteger, LGErrorCodes) {
    /** Success */
    kLGErrorSuccess,
    /** Error when trying to install privileged helper tool */
    kLGErrorInstallingPrivilegedHelperTool,
    /** Error when sending email fails */
    kLGErrorSendingEmail,
    /** Error when testing port failed */
    kLGErrorTestingPort,
    /** Error when some preferences could not be repaired, and values were removed */
    kLGErrorReparingAutoPkgPrefs,
    /** Error when attempting to spawn multiple instances of `autopkg run` at a time */
    kLGErrorMultipleRunsOfAutopkg,
    /** Error when trying to enable a recipe when the Parent Recipe is not avaliable */
    kLGErrorMissingParentRecipe,
    /** Error creating, reading or writing a recipe_list.txt file */
    kLGErrorRecipeListFileAccess,
    /** Generic error installing */
    kLGErrorInstallingGeneric,
    /** Error serializing xml object */
    kLGErrorJSSXMLSerializerError,
    /** Error Schedule timer incorrect */
    kLGErrorIncorrectScheduleTimerInterval,
    /** Error creating authorization*/
    kLGErrorKeychainAccess,
    /** Error creating authorization*/
    kLGErrorAuthChallenge,
};

#pragma mark - AutoPkg specific Error codes
typedef NS_ENUM(NSInteger, LGErrorAutoPkgCodes) {
    /** AutoPkg often returns -1 on when misconfigured */
    kLGErrorAutoPkgConfig = -1,

    /** AutoPkg returns 255 if no recipe is specified */
    kLGErrorAutoPkgNoRecipes = 255,

};

@interface LGError : NSObject

#ifdef _APPKITDEFINES_H
+ (void)presentErrorWithCode:(LGErrorCodes)code;
+ (void)presentErrorWithCode:(LGErrorCodes)code window:(NSWindow *)window;
+ (void)presentErrorWithCode:(LGErrorCodes)code
                      window:(NSWindow *)window
                    delegate:(id)sender
          didPresentSelector:(SEL)selector;
#endif

#pragma mark - AutoPkgr Defined Errors

/**
 *  Populate an NSError Object for AutoPkgr
 *
 *  @param code  cooresponging LGErrorCodes
 *  @param error __autoreleasing NSError object
 *
 *  @return NO if error occurred and error.code is not 0, otherwise YES;
 */
+ (BOOL)errorWithCode:(LGErrorCodes)code error:(NSError **)error;

/**
 *  Generate an NSError Object for AutoPkgr
 *
 *  @param code  cooresponging LGErrorCodes
 *
 *  @return Populated NSError Object if error code is != kLGErrorSuccess, nil otherwise;
 */
+ (NSError *)errorWithCode:(LGErrorCodes)code;

/**
 *  Create an NSError using an NSTask's stdout and exit code to populate the value
 *
 *  @param task completed NSTask object
 *
 *  @return populated NSError object if task's exit code != 0;
 */
+ (NSError *)errorFromTask:(NSTask *)task;

#pragma mark - NSURLConnection response Error
+ (BOOL)errorWithResponse:(NSHTTPURLResponse *)response error:(NSError **)error;
+ (NSError *)errorWithResponse:(NSHTTPURLResponse *)response;

@end
