//
//  NSFileManager+authorized.m
//  AHLaunchCtl
//
//  Created by Eldon on 2/19/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "NSFileManger+Privileged.h"
#import "AHAuthorizer.h"
#import "AHServiceManagement.h"

static NSString* kNSFileManagerCopyFile = @"com.eeaapps.launchctl.filecopy";
static NSString* kNSFileManagerMoveFile = @"com.eeaapps.launchctl.filemove";
static NSString* kNSFileManagerDeleteFile = @"com.eeaapps.launchctl.filedelete";

static NSString* kNSFileManagerChownFile = @"com.eeaapps.launchctl.filechown";
static NSString* kNSFileManagerChmodFile = @"com.eeaapps.launchctl.filechmod";

static NSString* kNSFileManagerErrFileNotDirectory =
    @"You specified a file not a directory";
static NSString* kNSFileManagerErrDirectoryNotFile =
    @"You specified a directory not a file";
static NSString* kNSFileManagerErrNoFileAtLocation =
    @"there was no file found at specified location";
static NSString* kNSFileManagerErrNoDirectoryAtLocation =
    @"there was no folder found at that location";

@implementation NSFileManager (Privileged)

- (BOOL)moveItemAtPath:(NSString*)path
    toPrivilegedLocation:(NSString*)location
               overwrite:(BOOL)overwrite
                   error:(NSError* __autoreleasing*)error
{
    AHLaunchJob* job;
    if (![self testSource:path andDest:location error:error]) {
    }
    
    AuthorizationRef authRef = [AHAuthorizer authorizeSystemDaemonWithPrompt:@""];
    if (authRef == NULL) {
        return NO;
    };
    
    job = [self FileManagerJob];
    job.Label = kNSFileManagerMoveFile;
    job.ProgramArguments = @[ @"/bin/mv", path, location ];

    return AHJobSubmit(kAHSystemLaunchDaemon, job.dictionary, authRef, error) == 0 ? YES:NO;

}

- (BOOL)copyItemAtPath:(NSString*)path
    toPrivilegedLocation:(NSString*)location
               overwrite:(BOOL)overwrite
                   error:(NSError**)error
{
    AHLaunchJob* job;
    if (![self testSource:path andDest:location error:error]) {
        return NO;
    }

    AuthorizationRef authRef = [AHAuthorizer authorizeSystemDaemonWithPrompt:@""];
    if (authRef == NULL) {
        return NO;
    };

    job = [self FileManagerJob];
    job.Label = kNSFileManagerCopyFile;
    job.ProgramArguments = @[ @"/bin/cp", @"-a", path, location ];

    return AHJobSubmit(kAHSystemLaunchDaemon, job.dictionary, authRef, error);
}

- (BOOL)deleteItemAtPrivilegedPath:(NSString*)path
                             error:(NSError* __autoreleasing*)error
{
    AHLaunchJob* job;
    if (![self fileExistsAtPath:path]) {
        return NO;
    }

    AuthorizationRef authRef = [AHAuthorizer authorizeSystemDaemonWithPrompt:@""];
    if (authRef == NULL) {
        return NO;
    };

    job = [self FileManagerJob];
    job.Label = kNSFileManagerCopyFile;
    job.ProgramArguments = @[ @"/bin/rm", path ];

    return AHJobSubmit(kAHSystemLaunchDaemon, job.dictionary, authRef, error);
}

- (BOOL)setAttributes:(NSDictionary*)attributes
    ofItemAtPrivilegedPath:(NSString*)path
                     error:(NSError* __autoreleasing*)error
{
    AHLaunchJob* job;
    BOOL rc = NO;
    if ([self fileExistsAtPath:path isDirectory:nil]) {
        AuthorizationRef authRef =
            [AHAuthorizer authorizeSystemDaemonWithPrompt:@""];
        if (authRef == NULL) {
            return NO;
        };

        NSNumber* permissions = attributes[NSFilePosixPermissions];
        NSString* owner = attributes[NSFileOwnerAccountName];
        NSString* group = attributes[NSFileGroupOwnerAccountName];

        NSMutableString* chown;
        if (permissions) {
            job = [self FileManagerJob];

            job.Label = kNSFileManagerChmodFile;
            job.ProgramArguments =
                @[ @"/bin/chmod", [permissions stringValue], path ];
            rc = AHJobSubmit(kAHSystemLaunchDaemon, job.dictionary, authRef, error);
        }

        if (owner || group) {
            job = [self FileManagerJob];
            job.Label = kNSFileManagerChownFile;

            chown = [[NSMutableString alloc]
                initWithCapacity:owner.length + group.length + 1];
            if (owner)
                [chown appendString:owner];
            if (group)
                [chown appendFormat:@":%@", group];

            job.ProgramArguments = @[ @"/usr/sbin/chown", chown, path ];
            rc = AHJobSubmit(kAHSystemLaunchDaemon, job.dictionary, authRef, error);
        }
        [AHAuthorizer authoriztionFree:authRef];
    }
    return rc;
}

- (BOOL)testSource:(NSString*)source
           andDest:(NSString*)dest
             error:(NSError* __autoreleasing*)error
{
    BOOL rc;
    if ([self fileExistsAtPath:source isDirectory:&rc]) {
        if (rc) {
            return [AHLaunchCtl errorWithMessage:kNSFileManagerErrDirectoryNotFile
                                         andCode:1
                                           error:error];
        }
    } else {
        return [AHLaunchCtl errorWithMessage:kNSFileManagerErrNoFileAtLocation
                                     andCode:1
                                       error:error];
    }
    if ([self fileExistsAtPath:dest isDirectory:&rc]) {
        if (!rc) {
            return [AHLaunchCtl errorWithMessage:kNSFileManagerErrFileNotDirectory
                                         andCode:1
                                           error:error];
        }
    } else {
        return [AHLaunchCtl errorWithMessage:kNSFileManagerErrNoDirectoryAtLocation
                                     andCode:1
                                       error:error];
    }
    return YES;
}

- (AHLaunchJob*)FileManagerJob
{
    AHLaunchJob* job = [AHLaunchJob new];
    job.LaunchOnlyOnce = YES;
    job.RunAtLoad = YES;
    return job;
}
@end
