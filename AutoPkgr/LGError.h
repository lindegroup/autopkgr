//
//  LGError.h
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

#import <Foundation/Foundation.h>

void DLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

#pragma mark - AutoPkgr specific Error codes
typedef NS_ENUM(NSInteger, LGErrorCodes) {
    /** Success */
    kLGErrorSuccess,
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
    /** Error installing Git */
    kLGErrorInstallGit,
    /** Error installing/updating AutoPkg */
    kLGErrorInstallAutoPkg,
    /** Error installing/updating AutoPkgr */
    kLGErrorInstallAutoPkgr,
    /** Error installing JSSImporter */
    kLGErrorInstallJSSImporter,
    /** Generic error installing */
    kLGErrorInstallingGeneric,
    /** Error serializing xml object */
    kLGErrorJSSXMLSerializerError,
    /** Error Schedule timer incorrect */
    kLGErrorIncorrectScheduleTimerInterval,
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

typedef NS_ENUM(NSInteger, LGAutoPkgVerb) {
    kLGAutoPkgUndefinedVerb,
    // recipe verbs
    kLGAutoPkgRun,
    kLGAutoPkgRecipeList,
    kLGAutoPkgMakeOverride,
    kLGAutoPkgSearch,

    // repo verbs
    kLGAutoPkgRepoAdd,
    kLGAutoPkgRepoDelete,
    kLGAutoPkgRepoUpdate,
    kLGAutoPkgRepoList,

    // other verbs
    kLGAutoPkgVersion,
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
 *  @return NO if error occured and error.code is not 0, otherwise YES;
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

#pragma mark - NSTask Error
/**
 *  Populate an NSError using a completed NSTask
 *
 *  @param task  Completed NSTask Object
 *  @param verb  Cooresponding Action Word Describing the AutoPkgr task process
 *  @param error __autoreleasing NSError object
 *
 *  @return NO if error occured and the exit code is not 0, otherwise YES;
 *  @discussion If the task is not complete this will return YES;
 */
+ (BOOL)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgVerb)verb error:(NSError **)error;
/**
 *  Generated NSError Object from and AutoPkgr NSTask
 *
 *  @param task  Completed NSTask Object
 *  @param verb  Cooresponding Action Word Describing the AutoPkgr task process
 *
 *  @return Populated NSError Object if exit status is != kLGErrorSuccess, nil otherwise;
 *  @discussion If the returned object will be nil if the task has not complete;
 */
+ (NSError *)errorWithTaskError:(NSTask *)task verb:(LGAutoPkgVerb)verb;

#pragma mark - NSURLConnection response Error
+ (BOOL)errorWithResponse:(NSHTTPURLResponse *)response error:(NSError **)error;
+ (NSError *)errorWithResponse:(NSHTTPURLResponse *)response;

@end
