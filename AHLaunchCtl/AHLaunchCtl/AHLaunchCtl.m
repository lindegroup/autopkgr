//  AHLaunchCtl.m
//  Copyright (c) 2014 Eldon Ahrold ( https://github.com/eahrold/AHLaunchCtl )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AHLaunchCtl.h"
#import "AHAuthorizer.h"
#import "AHServiceManagement.h"
#import <SystemConfiguration/SystemConfiguration.h>

NSString* const kAHLaunchCtlHelperTool = @"com.eeaapps.launchctl.helper";

static NSString* errorMsgFromCode(NSInteger code);
static NSString* launchFileDirectory(AHLaunchDomain domain);
static NSString* launchFile(NSString* label, AHLaunchDomain domain);
static BOOL jobIsRunning(NSString* label, AHLaunchDomain domain);
static BOOL jobExists(NSString* label, AHLaunchDomain domain);
static BOOL setToConsoleUser();
static BOOL resetToOriginalUser(uid_t uid);

typedef NS_ENUM(NSInteger, AHLaunchCtlErrorCodes) {
    kAHErrorJobLabelNotValid = 1001,
    kAHErrorJobMissingRequiredKeys,
    kAHErrorJobNotLoaded,
    kAHErrorJobAlreayExists,
    kAHErrorJobAlreayLoaded,
    kAHErrorCouldNotLoadJob,
    kAHErrorCouldNotLoadHelperTool,
    kAHErrorCouldNotUnloadJob,
    kAHErrorJobCouldNotReload,
    kAHErrorFileNotFound,
    kAHErrorCouldNotWriteFile,
    kAHErrorMultipleJobsMatching,
    kAHErrorInsufficentPriviledges,
    kAHErrorExecutingAsIncorrectUser,
    kAHErrorProgramNotExecutable,
};

@interface AHLaunchJob ()
@property (nonatomic, readwrite) AHLaunchDomain domain; //
@end

#pragma mark - Launch Controller
@implementation AHLaunchCtl

+ (AHLaunchCtl*)sharedControler
{
    static dispatch_once_t onceToken;
    static AHLaunchCtl* shared;
    dispatch_once(&onceToken, ^{ shared = [AHLaunchCtl new]; });
    return shared;
}

#pragma mark--- Add/Remove ---

- (BOOL)add:(AHLaunchJob*)job
    toDomain:(AHLaunchDomain)domain
       error:(NSError* __autoreleasing*)error
{
    if(![self hasProperPriviledgeLevel:domain]){
        return [[self class] errorWithCode:kAHErrorInsufficentPriviledges
                                     error:error];
    }
    
    uid_t uid = getuid();
    BOOL rc = NO;
    if (domain > kAHUserLaunchAgent) {
        job = [AHLaunchJob jobFromDictionary:job.dictionary];
    }

    if (!job.Label) {
        return [[self class] errorWithCode:kAHErrorJobMissingRequiredKeys error:error];
    }

    if ([self writeJobToFile:job inDomain:domain error:error]) {
        if (domain < kAHGlobalLaunchDaemon) {
            if (!setToConsoleUser())
                return [[self class] errorWithCode:kAHErrorExecutingAsIncorrectUser
                                             error:error];
        }
        rc = [self load:job inDomain:domain error:error];
        resetToOriginalUser(uid);
    }
    return rc;
}

- (BOOL)remove:(NSString*)label
    fromDomain:(AHLaunchDomain)domain
         error:(NSError* __autoreleasing*)error
{
    if(![self hasProperPriviledgeLevel:domain]){
        return [[self class] errorWithCode:kAHErrorInsufficentPriviledges
                                     error:error];
    }

    uid_t uid = getuid();
    if (domain < kAHGlobalLaunchDaemon) {
        if (!setToConsoleUser())
            return [[self class] errorWithCode:kAHErrorExecutingAsIncorrectUser
                                         error:error];
    }
    [self unload:label inDomain:domain error:error];
    resetToOriginalUser(uid);
    return [self removeJobFileWithLabel:label domain:domain error:error];
}

#pragma mark--- Load / Unload Jobs ---
- (BOOL)load:(AHLaunchJob*)job
    inDomain:(AHLaunchDomain)domain
       error:(NSError* __autoreleasing*)error
{
    if(![self hasProperPriviledgeLevel:domain]){
        return [[self class] errorWithCode:kAHErrorInsufficentPriviledges
                                     error:error];
    }

    BOOL rc;
    AuthorizationRef authRef = NULL;

    // If this is a launch agent and no user is logged in no reason to load;
    if (domain <= kAHSystemLaunchAgent) {
        NSString* result = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL));
        if ([result isEqualToString:@"loginwindow"] || !result) {
            NSLog(@"No User Logged in");
            return YES;
        }
    }

    if (domain >= kAHSystemLaunchAgent) {
        authRef = [AHAuthorizer authorizeSystemDaemonWithPrompt:@"Load Job?"];
    }

    rc = AHJobSubmit(domain, job.dictionary, authRef, error);

    if (rc) {
        job.domain = domain;
    }

    [AHAuthorizer authoriztionFree:authRef];
    return rc;
}

- (BOOL)unload:(NSString*)label
      inDomain:(AHLaunchDomain)domain
         error:(NSError* __autoreleasing*)error
{
    if(![self hasProperPriviledgeLevel:domain]){
        return [[self class] errorWithCode:kAHErrorInsufficentPriviledges
                                     error:error];
    }

    if (!jobIsRunning(label, domain)) {
        return [[self class] errorWithCode:kAHErrorJobNotLoaded error:error];
    }

    BOOL rc;
    AuthorizationRef authRef = NULL;

    // If this is a launch agent and no user is logged in no reason to load;
    if (domain <= kAHSystemLaunchAgent) {
        NSString* result = CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, NULL, NULL));
        if ([result isEqualToString:@"loginwindow"] || !result) {
            NSLog(@"No User Logged in");
            return YES;
        }
    }

    if (domain >= kAHSystemLaunchAgent)
        authRef = [AHAuthorizer authorizeSystemDaemonWithPrompt:nil];

    rc = AHJobRemove(domain, label, authRef, error);
    [AHAuthorizer authoriztionFree:authRef];
    return rc;
}

- (BOOL)reload:(AHLaunchJob*)job
      inDomain:(AHLaunchDomain)domain
         error:(NSError* __autoreleasing*)error
{
    if (jobIsRunning(job.Label, domain)) {
        if (![self unload:job.Label inDomain:domain error:error]) {
            return [[self class] errorWithCode:kAHErrorJobCouldNotReload error:error];
        }
    }
    return [self load:job inDomain:domain error:error];
}

#pragma mark--- Start / Stop / Restart ---
- (BOOL)start:(NSString*)label
     inDomain:(AHLaunchDomain)domain
        error:(NSError* __autoreleasing*)error
{
    if (jobIsRunning(label, domain)) {
        return [[self class] errorWithCode:kAHErrorJobAlreayLoaded error:error];
    }

    AHLaunchJob* job = [[self class] jobFromFileNamed:label inDomain:domain];
    if (job) {
        return [self load:job inDomain:domain error:error];
    } else {
        return [[self class] errorWithCode:kAHErrorFileNotFound error:error];
    }
}

- (BOOL)stop:(NSString*)label
    inDomain:(AHLaunchDomain)domain
       error:(NSError* __autoreleasing*)error
{
    return [self unload:label inDomain:domain error:error];
}

- (BOOL)restart:(NSString*)label
       inDomain:(AHLaunchDomain)domain
          error:(NSError* __autoreleasing*)error
{
    AHLaunchJob* job = [[self class] runningJobWithLabel:label inDomain:domain];
    if (!job) {
        return [[self class] errorWithCode:kAHErrorJobNotLoaded error:error];
    }
    return [self reload:job inDomain:domain error:error];
}

- (BOOL)shouldLoadJob:(BOOL)load
          shouldStick:(BOOL)wKey
                label:(NSString*)label
               domain:(AHLaunchDomain)domain
                error:(NSError* __autoreleasing*)error
{
    NSTask* task = [NSTask new];
    task.launchPath = @"/bin/launchctl";
    NSMutableArray* args = [[NSMutableArray alloc] initWithCapacity:3];
    if (load) {
        [args addObjectsFromArray:@[ @"load", launchFile(label, domain) ]];
    } else {
        [args addObjectsFromArray:@[ @"remove", label ]];
    }

    if (wKey)
        [args insertObject:@"-w" atIndex:1];
    task.arguments = args;

    [task launch];
    [task waitUntilExit];
    if (task.terminationStatus != 0) {
        if (load)
            return [[self class] errorWithCode:kAHErrorCouldNotLoadJob error:error];

        return [[self class] errorWithCode:kAHErrorCouldNotUnloadJob error:error];
    }
    return YES;
}

#pragma mark--- File Writing ---
- (BOOL)writeJobToFile:(AHLaunchJob*)job
              inDomain:(AHLaunchDomain)domain
                 error:(NSError* __autoreleasing*)error
{
    NSFileManager* fm = [NSFileManager new];

    BOOL rc = NO;
    if (![fm isExecutableFileAtPath:job.Program]) {
        if ([job.ProgramArguments objectAtIndex:0]) {
            if (![fm isExecutableFileAtPath:job.ProgramArguments[0]]) {
                return [[self class] errorWithCode:kAHErrorProgramNotExecutable
                                             error:error];
            }
        } else {
            return NO;
        }
    }

    NSString* file = launchFile(job.Label, domain);
    rc = [job.dictionary writeToFile:file atomically:YES];
    if (!rc) {
        return [[self class] errorWithCode:kAHErrorCouldNotWriteFile error:error];
    };

    if (domain > kAHUserLaunchAgent) {
        rc = [fm setAttributes:@{
            NSFilePosixPermissions : [NSNumber numberWithInt:0644],
            NSFileOwnerAccountName : @"root",
            NSFileGroupOwnerAccountName : @"wheel"
        } ofItemAtPath:file
                         error:error];
    }
    return rc;
}

- (BOOL)removeJobFileWithLabel:(NSString*)label
                        domain:(AHLaunchDomain)domain
                         error:(NSError* __autoreleasing*)error
{
    NSFileManager* fm = [NSFileManager new];
    NSString* file = launchFile(label, domain);
    if ([fm fileExistsAtPath:file isDirectory:NO]) {
        return [fm removeItemAtPath:file error:error];
    } else {
        return YES;
    }
}

#pragma mark - util
- (BOOL)hasProperPriviledgeLevel:(AHLaunchDomain)domain{
    uid_t uid = getuid();
    if (domain > kAHUserLaunchAgent && uid != 0){
        return NO;
    }
    return YES;
}

#pragma mark - Helper Tool Installation / Removal
+ (BOOL)installHelper:(NSString*)label
               prompt:(NSString*)prompt
                error:(NSError* __autoreleasing*)error
{
    NSString* currentVersion;
    NSString* avaliableVersion;

    AHLaunchJob* job =
        [[self class] runningJobWithLabel:label inDomain:kAHGlobalLaunchDaemon];
    if (job) {
        currentVersion = job.executableVersion;

        NSString* xpcToolPath = [NSString
            stringWithFormat:@"Contents/Library/LaunchServices/%@", label];
        NSURL* appBundleURL = [[NSBundle mainBundle] bundleURL];
        NSURL* helperTool = [appBundleURL URLByAppendingPathComponent:xpcToolPath];
        NSDictionary* helperPlist = (NSDictionary*)CFBridgingRelease(
            CFBundleCopyInfoDictionaryForURL((__bridge CFURLRef)(helperTool)));

        avaliableVersion = helperPlist[@"CFBundleVersion"];

        if (![[self class] version:avaliableVersion
                isGreaterThanVersion:currentVersion]) {
            return YES;
        }
    }

    BOOL rc = YES;
    AuthorizationRef authRef;

    authRef = [AHAuthorizer authorizeSMJobBlessWithPrompt:prompt];
    if (authRef == NULL) {
        rc =
            [[self class] errorWithCode:kAHErrorInsufficentPriviledges error:error];
    } else {
        if (!AHJobBless(kAHSystemLaunchDaemon, label, authRef, error)) {
            rc = [[self class] errorWithCode:kAHErrorCouldNotLoadHelperTool
                                       error:error];
        }
    }
    [AHAuthorizer authoriztionFree:authRef];
    return rc;
}

+ (BOOL)uninstallHelper:(NSString*)label
                  error:(NSError* __autoreleasing*)error
{
    BOOL rc = NO;
    NSString* helperLaunchFile =
        [NSString stringWithFormat:@"/Library/LaunchDaemons/%@.plist", label];
    NSString* helperTool =
        [NSString stringWithFormat:@"/Library/PrivilegedHelperTools/%@", label];
    rc = [[NSFileManager defaultManager] removeItemAtPath:helperLaunchFile
                                                    error:error];
    if (!rc)
        NSLog(@"Couldn't remove helper launchctl file");

    rc = [[NSFileManager defaultManager] removeItemAtPath:helperTool error:error];
    if (!rc)
        NSLog(@"Couldn't remove helper tool");

    return [[AHLaunchCtl sharedControler] unload:label
                                        inDomain:kAHGlobalLaunchDaemon
                                           error:error];
}

+ (BOOL)version:(NSString*)versionA isGreaterThanVersion:(NSString*)versionB
{
    NSMutableArray* bVer = [[NSMutableArray alloc]
        initWithArray:
            [NSArray arrayWithArray:[versionB componentsSeparatedByString:@"."]]];

    NSMutableArray* aVer = [[NSMutableArray alloc]
        initWithArray:
            [NSArray arrayWithArray:[versionA componentsSeparatedByString:@"."]]];

    NSInteger max = 3;

    while (aVer.count < max) {
        [aVer addObject:@"0"];
    }

    while (bVer.count < max) {
        [bVer addObject:@"0"];
    }

    for (NSInteger i = 0; i < max; i++) {
        if ([[aVer objectAtIndex:i] integerValue] >
            [[bVer objectAtIndex:i] integerValue]) {
            return YES;
        }
    }
    return NO;
}


#pragma mark - Convience Accessors
+ (BOOL)launchAtLogin:(NSString*)app
               launch:(BOOL)launch
               global:(BOOL)global
            keepAlive:(BOOL)keepAlive
                error:(NSError* __autoreleasing*)error
{
    NSBundle* appBundle = [NSBundle bundleWithPath:app];
    NSString* appIdentifier =
        [NSString stringWithFormat:@"%@.launcher", appBundle.bundleIdentifier];

    AHLaunchCtl* controller = [AHLaunchCtl new];
    AHLaunchJob* job = [AHLaunchJob new];
    job.Label = appIdentifier;
    job.Program = appBundle.executablePath;
    job.RunAtLoad = YES;
    job.KeepAlive = @{ @"SuccessfulExit" : [NSNumber numberWithBool:keepAlive] };

    AHLaunchDomain domain = global ? kAHGlobalLaunchAgent : kAHUserLaunchAgent;
    if (launch) {
        return [controller add:job toDomain:domain error:error];
    } else {
        return [controller remove:job.Label fromDomain:domain error:error];
    }
}

+ (void)scheduleJob:(NSString*)label
            program:(NSString*)program
           interval:(int)seconds
             domain:(AHLaunchDomain)domain
              reply:(void (^)(NSError* error))reply
{
    [self scheduleJob:label
                 program:program
        programArguments:nil
                interval:seconds
                  domain:domain
                   reply:^(NSError* error) { reply(error); }];
}

+ (void)scheduleJob:(NSString*)label
             program:(NSString*)program
    programArguments:(NSArray*)programArguments
            interval:(int)seconds
              domain:(AHLaunchDomain)domain
               reply:(void (^)(NSError* error))reply
{
    AHLaunchCtl* controller = [AHLaunchCtl new];
    AHLaunchJob* job = [AHLaunchJob new];
    job.Label = label;
    job.Program = program;
    job.ProgramArguments = programArguments;
    job.RunAtLoad = YES;
    job.StartInterval = seconds;
    
    NSError *error;
    [controller add:job toDomain:domain error:&error];
    reply(error);
}

#pragma mark--- Get Job ---
+ (AHLaunchJob*)jobFromFileNamed:(NSString*)label
                        inDomain:(AHLaunchDomain)domain
{
    NSArray* jobs = [self allJobsFromFilesInDomain:domain];
    if ([label.pathExtension isEqualToString:@"plist"])
        label = [label stringByDeletingPathExtension];

    NSPredicate* predicate =
        [NSPredicate predicateWithFormat:@"%@ == SELF.Label ", label];

    for (AHLaunchJob* job in jobs) {
        if ([predicate evaluateWithObject:job]) {
            return job;
        }
    }
    return nil;
}

+ (AHLaunchJob*)runningJobWithLabel:(NSString*)label
                           inDomain:(AHLaunchDomain)domain
{
    AHLaunchJob* job;
    NSDictionary* dict = AHJobCopyDictionary(domain, label);
    // for some system processes the dict can return nil, so we have a more
    // expensive back-up in that case;
    if (dict.count) {
        job = [AHLaunchJob jobFromDictionary:dict];
    } else {
        job = [[[self class] runningJobsMatching:label inDomain:domain] lastObject];
    }

    return job;
}

#pragma mark--- Get Array Of Jobs ---
+ (NSArray*)allRunningJobsInDomain:(AHLaunchDomain)domain
{
    return [self jobMatch:nil domain:domain];
}

+ (NSArray*)runningJobsMatching:(NSString*)match
                       inDomain:(AHLaunchDomain)domain
{
    NSPredicate* predicate = [NSPredicate
        predicateWithFormat:
            @"SELF.Label CONTAINS[c] %@ OR SELF.Program CONTAINS[c] %@", match,
            match];
    return [self jobMatch:predicate domain:domain];
}

+ (NSArray*)allJobsFromFilesInDomain:(AHLaunchDomain)domain
{
    AHLaunchJob* job;
    NSMutableArray* jobs;
    NSString* launchDirectory = launchFileDirectory(domain);
    NSArray* launchFiles =
        [[NSFileManager defaultManager] contentsOfDirectoryAtPath:launchDirectory
                                                            error:nil];

    if (launchFiles.count) {
        jobs = [[NSMutableArray alloc] initWithCapacity:launchFiles.count];
    }

    for (NSString* file in launchFiles) {
        NSString* filePath =
            [NSString stringWithFormat:@"%@/%@", launchDirectory, file];
        NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:filePath];
        if (dict) {
            @try {
                job = [AHLaunchJob jobFromDictionary:dict];
                if (job)
                    job.domain = domain;
                [jobs addObject:job];
            }
            @catch (NSException* exception)
            {
                NSLog(@"error %@", exception);
            }
        }
    }
    return jobs;
}

+ (NSArray*)jobMatch:(NSPredicate*)predicate domain:(AHLaunchDomain)domain
{
    NSArray* array = AHCopyAllJobDictionaries(domain);
    if (!array.count)
        return nil;

    NSMutableArray* jobs = [[NSMutableArray alloc] initWithCapacity:array.count];
    for (NSDictionary* dict in array) {
        AHLaunchJob* job;
        if (predicate) {
            if ([predicate evaluateWithObject:dict]) {
                job = [AHLaunchJob jobFromDictionary:dict];
            }
        } else {
            job = [AHLaunchJob jobFromDictionary:dict];
        }
        if (job) {
            job.domain = domain;
            [jobs addObject:job];
        }
    }
    return [NSArray arrayWithArray:jobs];
}

#pragma mark - Error Codes
+ (BOOL)errorWithCode:(NSInteger)code error:(NSError* __autoreleasing*)error
{
    BOOL rc = code > 0 ? NO : YES;
    NSString* msg = errorMsgFromCode(code);
    NSError* err = [NSError errorWithDomain:@"com.eeaapps.launchctl"
                                       code:code
                                   userInfo:@{ NSLocalizedDescriptionKey : msg }];
    if (error)
        *error = err;
    else
        NSLog(@"Error: %@", msg);

    return rc;
}

+ (BOOL)errorWithMessage:(NSString*)message
                 andCode:(NSInteger)code
                   error:(NSError* __autoreleasing*)error
{
    BOOL rc = code > 0 ? NO : YES;
    NSError* err =
        [NSError errorWithDomain:@"com.eeaapps.launchctl"
                            code:code
                        userInfo:@{ NSLocalizedDescriptionKey : message }];
    if (error)
        *error = err;
    else
        NSLog(@"Error: %@", message);
    return rc;
}

+ (BOOL)errorWithCFError:(CFErrorRef)cfError
                    code:(int)code
                   error:(NSError* __autoreleasing*)error
{
    BOOL rc = code > 0 ? NO : YES;

    NSError* err = CFBridgingRelease(cfError);
    if (error)
        *error = err;
    else
        NSLog(@"Error: %@", err.localizedDescription);

    return rc;
}

@end

#pragma mark - Utility Functions

static BOOL jobIsRunning(NSString* label, AHLaunchDomain domain)
{
    NSDictionary* dict = AHJobCopyDictionary(domain, label);
    return dict ? YES : NO;
}

static BOOL jobExists(NSString* label, AHLaunchDomain domain)
{
    CFUserNotificationRef authNotification;
    CFOptionFlags responseFlags;
    SInt32 cfError;
    NSString* alertHeader;

    BOOL fileExists = [[NSFileManager defaultManager]
        fileExistsAtPath:launchFile(label, domain)];
    if (fileExists || jobIsRunning(label, domain)) {
        alertHeader =
            [NSString stringWithFormat:@"A job with the same label exists in this "
                      @"domain, would you like to overwrite?"];

        CFOptionFlags flags = kCFUserNotificationPlainAlertLevel | CFUserNotificationSecureTextField(1);

        NSDictionary* panelDict =
            [NSDictionary dictionaryWithObjectsAndKeys:
                              alertHeader, kCFUserNotificationAlertHeaderKey,
                              @"Cancel", kCFUserNotificationAlternateButtonTitleKey,
                              @"", kCFUserNotificationAlertMessageKey, nil];

        authNotification = CFUserNotificationCreate(kCFAllocatorDefault, 0, flags, &cfError,
                                                    (__bridge CFDictionaryRef)panelDict);

        cfError = CFUserNotificationReceiveResponse(authNotification, 0, &responseFlags);

        if (cfError) {
            CFRelease(authNotification);
            return YES;
        }
        int button = responseFlags & 0x1;

        if (button == kCFUserNotificationAlternateResponse) {
            CFRelease(authNotification);
            return YES;
        }
        CFRelease(authNotification);
        return NO;
    } else {
        return NO;
    }
}

static NSString* errorMsgFromCode(NSInteger code)
{
    NSString* msg;
    switch (code) {
    case kAHErrorJobNotLoaded:
        msg = @"Job not loaded";
        break;
    case kAHErrorFileNotFound:
        msg = @"we could not find the specified launchd.plist to load the job";
        break;
    case kAHErrorCouldNotLoadJob:
        msg = @"Could not load job";
        break;
    case kAHErrorCouldNotLoadHelperTool:
        msg = @"Unable to install the priviledged helper tool";
        break;
    case kAHErrorJobAlreayExists:
        msg = @"The specified job alreay exists";
        break;
    case kAHErrorJobAlreayLoaded:
        msg = @"The specified job is already loaded";
        break;
    case kAHErrorJobCouldNotReload:
        msg = @"There were problems reloading the job";
        break;
    case kAHErrorJobLabelNotValid:
        msg = @"The label is not valid. please format as a unique reverse domain";
        break;
    case kAHErrorCouldNotUnloadJob:
        msg = @"Could not unload job";
        break;
    case kAHErrorMultipleJobsMatching:
        msg = @"More than one job matched that description";
        break;
    case kAHErrorCouldNotWriteFile:
        msg = @"There were problem writing to the file";
        break;
    case kAHErrorInsufficentPriviledges:
        msg = @"You are not authorized to to perform this action";
        break;
    case kAHErrorJobMissingRequiredKeys:
        msg = @"The Submitted Job was missing some required keys";
        break;
    case kAHErrorExecutingAsIncorrectUser:
        msg = @"Could not set the Job to run in the proper context";
        break;
    case kAHErrorProgramNotExecutable:
        msg = @"The path specified doesn’t appear to be executable.";
        break;
    default:
        msg = @"unknown problem occured";
        break;
    }
    return msg;
}

static NSString* launchFileDirectory(AHLaunchDomain domain)
{
    NSString* type;
    NSString* fallback = [NSHomeDirectory()
        stringByAppendingPathComponent:@"%@/Library/LaunchAgents/"];
    switch (domain) {
    case kAHGlobalLaunchAgent:
        type = @"/Library/LaunchAgents/";
        break;
    case kAHGlobalLaunchDaemon:
        type = @"/Library/LaunchDaemons/";
        break;
    case kAHSystemLaunchAgent:
        type = @"/System/Library/LaunchAgents/";
        break;
    case kAHSystemLaunchDaemon:
        type = @"/System/Library/LaunchDaemons/";
        break;
    case kAHUserLaunchAgent:
        type = fallback;
        break;
    default:
        type = fallback;
        break;
    }
    return type;
}

static NSString* launchFile(NSString* label, AHLaunchDomain domain)
{
    NSString* file;
    if (domain == 0 || !label)
        return nil;
    file = [NSString
        stringWithFormat:@"%@/%@.plist", launchFileDirectory(domain), label];
    return file;
}

static BOOL setToConsoleUser()
{
    uid_t effectiveUid;
    int results;

    CFBridgingRelease(SCDynamicStoreCopyConsoleUser(NULL, &effectiveUid, NULL));
    results = seteuid(effectiveUid);

    if (results != 0)
        return NO;
    else
        return YES;
}

static BOOL resetToOriginalUser(uid_t uid)
{
    int results;
    results = seteuid(uid);
    if (results != 0)
        return NO;
    else
        return YES;
}
