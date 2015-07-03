//
//  LGPackageRemover.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGPackageRemover.h"
#import "LGConstants.h"

#import "NSData+taskData.h"
#import <syslog.h>

typedef NS_ENUM(OSStatus, LGPackageInsallerError) {
    kLGPackageInstallerErrorSuccess = 0,
    kLGPackageInstallerErrorIncompleteRemoval,
    kLGPackageInstallerErrorPackageNotRemovable,
    kLGPackageInstallerErrorNoFilesSpecified,
};

static NSString *const kLGPackageRemoverRecieptsDir = @"/private/var/db/receipts";
static NSString *const DS_STORE = @".DS_Store";
static NSString *const PYTHON_BYTECODE_EXTENSION = @"pyc";

static NSDictionary *errorInfoFromCode(LGPackageInsallerError code, NSString *identifier)
{
    NSString *fmtString;
    NSString *suggestion;
    const NSString *specified = @"specified";
    switch (code) {
    case kLGPackageInstallerErrorSuccess:
        fmtString = @"Successfully removed the %@ package";
        suggestion = @"";
        break;
    case kLGPackageInstallerErrorIncompleteRemoval:
        fmtString = @"Did not successfully remove all files specified in the %@ package.";
        suggestion = @"Some of the files the installer package was responsible for remain on the your system. You may need to remove them manually.";
        break;
    case kLGPackageInstallerErrorPackageNotRemovable:
        fmtString = @"Removing the %@ package is not currently allowed";
        suggestion = @"";
        break;
    case kLGPackageInstallerErrorNoFilesSpecified:
        fmtString = @"No files were found for the %@ package";
        suggestion = @"";
        break;
    default:
        fmtString = @"Unknown Error [%@]";
        suggestion = @"";
    }

    return @{ NSLocalizedDescriptionKey : [NSString stringWithFormat:fmtString, identifier ?: specified],
              NSLocalizedDescriptionKey : suggestion };
}

static dispatch_queue_t autopkgr_pkg_remover_queue()
{
    static dispatch_queue_t autopkgr_recipe_write_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        autopkgr_recipe_write_queue = dispatch_queue_create("com.lindegroup.autopkgr.pkg.remover.queue", DISPATCH_QUEUE_SERIAL );
    });

    return autopkgr_recipe_write_queue;
}


@implementation LGPackageRemover

- (instancetype)init
{
    if (self = [super init]) {
        _dryRun = YES;
    }
    return self;
}

- (NSArray *)filesForIdentifier:(NSString *)identifier
{
    return [[self bomForIdentifiers:@[ identifier ] error:nil] array];
}

- (void)removePackageWithIdentifier:(NSString *)identifier progress:(void (^)(NSString *, double))progress reply:(void (^)(NSArray *, NSArray *, NSError *))reply
{
    [self removePackagesWithIdentifiers:@[ identifier ] progress:progress reply:reply];
}

- (void)removePackagesWithIdentifiers:(NSArray *)identifiers progress:(void (^)(NSString *, double))progress reply:(void (^)(NSArray *successfullyRemoved, NSArray *failedToRemove, NSError *error))reply
{

    BOOL dryRun = _dryRun;

    NSArray *installedPackages = [[self class] installedPackages];
    NSArray *validRemovablePackages = [[self class] validRemovablePackages];
    NSMutableArray *validIdentifiers = [identifiers mutableCopy];

    __block NSError *error;
    if (!_dryRun) {
        for (NSString *identifier in identifiers) {
            if (![installedPackages containsObject:identifier]) {
                [validIdentifiers removeObject:identifier];
                syslog(LOG_ALERT, "%s is not currently installed, removing it from the list of pkgs to consider.", identifier.UTF8String);
            } else if (![validRemovablePackages containsObject:identifier]) {
                error = [[self class] errorWithCode:kLGPackageInstallerErrorPackageNotRemovable identifier:identifier];
                return reply(nil, nil, error);
            }
        }
    }

    dispatch_async(autopkgr_pkg_remover_queue(), ^{
        NSMutableArray *files = [[NSMutableArray alloc] init];
        NSArray *valideIdentifiers = [[self bomForIdentifiers:validIdentifiers error:&error] array];
        if (valideIdentifiers.count) {
            [files addObjectsFromArray:valideIdentifiers];
        }

        // Remove the files...
        double count = 0.0;
        double total = files.count;

        NSMutableArray *removed = [[NSMutableArray alloc] initWithCapacity:total];
        NSMutableArray *remain = [[NSMutableArray alloc] initWithCapacity:total];

        NSFileManager *fm = [NSFileManager defaultManager];
        [files sortUsingSelector:@selector(localizedStandardCompare:)];

        // Now go through and remove the directories in our list...
        for (NSString *path in [[files reverseObjectEnumerator] allObjects]){
            count++;
            double p = ((count/total) * 100);
            NSString *progressMessage;
            BOOL isDir;
            if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
                NSError *error = nil;
                if (isDir) {
                    if (dryRun) {
                        progressMessage = [NSString stringWithFormat:@"Will try to remove dir:  %@", path];
                    } else if ( [[fm contentsOfDirectoryAtPath:path error:&error] count] || error) {
                        // The directory is not empty...
                        progressMessage = [NSString stringWithFormat:@"Could not remove non-empty directory %@", path];
                    } else if ([fm removeItemAtPath:path error:&error]) {
                        progressMessage = [NSString stringWithFormat:@"Removed dir:  %@", path];
                        [removed addObject:path];
                    }
                } else {
                    // It's a file
                    if (dryRun) {
                        progressMessage = [NSString stringWithFormat:@"Will try to remove file: %@", path];
                    } else if ([fm removeItemAtPath:path error:&error]) {
                        progressMessage = [NSString stringWithFormat:@"Removing file: %@", path];
                        [removed addObject:path];
                    }
                }
                if (error) {
                    progressMessage = [NSString stringWithFormat:@"%@", error.localizedDescription];
                    [remain addObject:path];
                }
            }

            if (dryRun) {
                [removed addObject:path];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                progress(progressMessage, p);
            });
        }


        for (NSString *identifier in validIdentifiers) {
            [self forget:identifier error:&error];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            reply(removed, remain, error);
        });
    });

}

- (BOOL)forget:(NSString *)identifer error:(NSError *__autoreleasing *)error
{
    NSArray *files = [[self bomForIdentifiers:@[ identifer ] error:error] array];
    return [self forget:identifer files:files error:error];
}

- (BOOL)forget:(NSString *)identifer files:(NSArray *)files error:(NSError *__autoreleasing *)error
{
    BOOL forgot = NO;
    if (files.count) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *file in files) {
            if ([fm fileExistsAtPath:file]) {
                if (error) {
                    *error = [[self class] errorWithCode:kLGPackageInstallerErrorIncompleteRemoval identifier:identifer];
                }
                return NO;
            }
        }
    }

    if ([[[self class] validRemovablePackages] containsObject:identifer]) {
        [[self class] pkgutilTaskWithArgs:@[ @"--forget", identifer ] error:error];
        forgot = YES;
    } else {
        forgot = NO;
    }

    return forgot;
}


- (NSMutableOrderedSet *)bomForIdentifiers:(NSArray *)identifiers error:(NSError *__autoreleasing *)error
{
    NSMutableOrderedSet *files = [[NSMutableOrderedSet alloc] init];
    NSMutableOrderedSet *directories = [[NSMutableOrderedSet alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];

    for (NSString *identifier in identifiers) {
        // Get the installer base path from.
        NSDictionary *recieptDictionary = [[[self class] pkgutilTaskWithArgs:@[ @"--pkg-info-plist", identifier ] error:error] taskData_serializedDictionary];

        NSString *installerBasePath = [recieptDictionary[@"volume"] stringByAppendingPathComponent:recieptDictionary[@"install-location"]];

        // Get the list of files.
        NSArray *tmpFileArray = [[[self class] pkgutilTaskWithArgs:@[ @"--files", identifier ] error:error] taskData_splitLines];

        if (tmpFileArray.count) {
            for (NSString *file in tmpFileArray) {
                BOOL isDir;
                NSString *normalizedFile = [installerBasePath stringByAppendingPathComponent:file];
                if ([fm fileExistsAtPath:normalizedFile isDirectory:&isDir]) {
                    if (isDir) {
                        [directories addObject:normalizedFile];
                    } else {
                        [files addObject:normalizedFile];
                    }
                }
            }
        }
    }

    // Go over the directory array and see if it will be empty once all of the
    // files in the file array are removed
    for (NSString *dir in [directories copy]) {
        NSArray *dirContents = [fm contentsOfDirectoryAtPath:dir error:nil];

        for (NSString *fileName in dirContents) {
            NSString *filePath = [dir stringByAppendingPathComponent:fileName];
            // If it's marked as a file type to be auto removed add it to the files array.
            if ([self evalAutoRemove:fileName]) {
                [files addObject:filePath];
            } else {

                // If there is a file in the current dir array that is not represented
                // in the fileArray the directory will not be empty so
                // remove the current dir from the array of directories to purge
                if (![files containsObject:filePath] && ![directories containsObject:filePath]) {
                    [directories removeObject:dir];
                    break;
                }
            }
        }
    }

    if (directories.array.count) {
        [files addObjectsFromArray:directories.array];
    }

    return files;
}

- (BOOL)evalAutoRemove:(NSString *)fileName
{
    BOOL autoRemove = NO;
    if ([fileName isEqualToString:DS_STORE]) {
        autoRemove = YES;
    } else if ([[[self class] autoRemoveFileExtensions] containsObject:fileName.pathExtension]) {
        autoRemove = YES;
    }
    return autoRemove;
}

#pragma mark - Class Methods
+ (NSData *)pkgutilTaskWithArgs:(NSArray *)arguments error:(NSError *__autoreleasing *)error
{

    // Collect the data into a mutable container.
    // NSTask's stdout buffer isn't unlimited and there are enough
    // Cases where the task can stall when to much data is sent.
    NSRecursiveLock *lock = [[NSRecursiveLock alloc] init];
    NSMutableData *outData = [[NSMutableData alloc] init];
    NSMutableData *errData = [[NSMutableData alloc] init];

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/pkgutil";
    task.arguments = arguments;

    task.standardOutput = [NSPipe pipe];
    [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
        [lock lock];
        [outData appendData:fh.availableData];
        [lock unlock];
    }];

    task.standardError = [NSPipe pipe];
    [[task.standardError fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
        [lock lock];
        [errData appendData:fh.availableData];
        [lock unlock];
    }];

    [task launch];
    [task waitUntilExit];

    if (error && errData.length && (task.terminationStatus != 0)) {
        NSString *errString = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding];
        *error = [NSError errorWithDomain:kLGApplicationName code:task.terminationStatus userInfo:@{ NSLocalizedDescriptionKey : @"There was a problem with pkgutil.",
                                                                                                     NSLocalizedRecoverySuggestionErrorKey : errString }];
    }

    if (outData.length) {
        return outData;
    }
    return nil;
}

+ (NSError *)errorWithCode:(LGPackageInsallerError)code identifier:(NSString *)identifier
{
    return [NSError errorWithDomain:kLGApplicationName code:code userInfo:errorInfoFromCode(code, identifier)];
}

+ (NSArray *)installedPackages
{
    return [[[self class] pkgutilTaskWithArgs:@[ @"--pkgs" ] error:nil] taskData_splitLines];
}

#pragma mark - Static declarations // For safety!
+ (NSArray *)validRemovablePackages
{
    static NSArray *packages;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        packages = @[@"com.github.sheagcraig.jssimporter",
                     @"com.github.sheagcraig.jss-autopkg-addon",
                     @"com.github.tburgin.AbsoluteManageExport",
                     ];
    });
    return packages;
}

+ (NSArray *)autoRemoveFileExtensions
{
    static NSArray *extensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        extensions = @[DS_STORE,
                       PYTHON_BYTECODE_EXTENSION,
                       ];
    });
    return extensions;
}

@end
