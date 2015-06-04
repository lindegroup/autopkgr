//
//  LGTools.m
//  AutoPkgr
//
//  Copyright 2015 Eldon Ahrold
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
//

#import "LGTool.h"
#import "LGTool+Protocols.h"

#import "LGAutoPkgr.h"

#import "LGInstaller.h"
#import "LGUninstaller.h"

#import "LGAutoPkgTask.h"
#import "LGHostInfo.h"

#ifndef LGTOOL_SUBCLASS
#define LGTOOL_SUBCLASS
#endif

// Dispatch queue for synchronizing infoHanler setter and refresh.
static dispatch_queue_t autopkgr_tool_synchronizer_queue()
{
    static dispatch_queue_t autopkgr_tool_synchronizer_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        autopkgr_tool_synchronizer_queue = dispatch_queue_create("com.lindegroup.autopkgr.tool.synchronizer.queue", DISPATCH_QUEUE_SERIAL );
    });

    return autopkgr_tool_synchronizer_queue;
}

NSString *const kLGNotificationToolStatusDidChange = @"com.lindegroup.autopkgr.notification.toolstatus.did.change";

@interface LGTool ()
@property (copy, nonatomic, readwrite) LGToolInfo *info;
@end

@interface LGToolInfo ()
- (instancetype)initWithTool:(LGTool *)tool;
@end

void subclassMustImplement(id className, SEL _cmd)
{
    NSString *reason = [NSString stringWithFormat:@"Subclass of %s must implement the method \"%s\".",
                                                  object_getClassName(className), sel_getName(_cmd)];
    @throw [NSException exceptionWithName:@"SubclassMustImplement"
                                   reason:reason
                                 userInfo:nil];
}

void subclassMustConformToProtocol(id className)
{
    NSString *reason = [NSString stringWithFormat:@"[ EXCEPTION ] %s must conform to at least one LGTool protocol",
                        object_getClassName(className)];
    @throw [NSException exceptionWithName:@"SubclassMustConform"
                                   reason:reason
                                 userInfo:nil];
}

@implementation LGTool {
    void (^_progressUpdateBlock)(NSString *, double);
    void (^_replyErrorBlock)(NSError *);
    NSMutableDictionary *_infoUpdateBlocksDict;
}

@synthesize installedVersion = _installedVersion;
@synthesize remoteVersion = _remoteVersion;
@synthesize gitHubInfo = _gitHubInfo;

#pragma mark - Protocol conform check
+ (void)initialize
{
    // We only need to check subclasses, the super
    if ((self != [LGTool class]) && [self isSubclassOfClass:[LGTool class]]) {

        // The subclasses must conform to at least one of the protocols
        if (([self conformsToProtocol:@protocol(LGToolSharedProcessor)] ||
             [self conformsToProtocol:@protocol(LGToolPackageInstaller)]) == NO)
        {
            subclassMustConformToProtocol(self);
        }
    }
}

#pragma mark - Tool
+ (BOOL)isInstalled
{
    if ((self.typeFlags & kLGToolTypeAutoPkgSharedProcessor) && (![self components])) {
        return [[LGAutoPkgTask repoList] containsObject:[self defaultRepository]];
    } else {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *file in self.components) {
            if (![fm fileExistsAtPath:file]) {
                return NO;
            }
        }
    }
    return YES;
}

+ (BOOL)isUninstallable
{
    return YES;
}

+ (BOOL)meetsRequirements:(NSError *__autoreleasing *)error
{
    return YES;
}

#pragma mark - Init / Dealloc
- (void)dealloc
{
    DevLog(@"Dealloc %@", self);

    // nil out the blocks to break retain cycles.
    _progressUpdateBlock = nil;
    _replyErrorBlock = nil;

    /* Repoint so we don't loose reference to the _infoUpdateBlockDict after dealloc */
    NSMutableDictionary *releaseDict = _infoUpdateBlocksDict;
    dispatch_async(autopkgr_tool_synchronizer_queue(), ^{
        [releaseDict enumerateKeysAndObjectsUsingBlock:^(void (^infoUpdate)(LGToolInfo *), id obj, BOOL *stop) {
            infoUpdate = nil;
        }];
        [releaseDict removeAllObjects];
    });
}

- (instancetype)init
{
    if (self = [super init]) {
        if ([[self class] typeFlags] & kLGToolTypeInstalledPackage) {
            self.gitHubInfo = [[LGGitHubReleaseInfo alloc] initWithURL:[[self class] gitHubURL]];
        }
    }
    return self;
}

#pragma mark - Subclass responsibility

+ (NSString *)name
{
    subclassMustImplement(self, _cmd);
    return nil;
}

+ (LGToolTypeFlags)typeFlags
{
    LGToolTypeFlags flags = kLGToolTypeUnspecified;
    if ([self conformsToProtocol:@protocol(LGToolSharedProcessor)]) {
        flags += kLGToolTypeAutoPkgSharedProcessor;
    }

    if ([self conformsToProtocol:@protocol(LGToolPackageInstaller)]) {
        flags += kLGToolTypeInstalledPackage;
    }

    if ([self isUninstallable]) {
        flags += kLGToolTypeUninstallableTool;
    }

    return flags;
}

+ (NSString *)binary
{
    if ([self typeFlags] & kLGToolTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSArray *)components
{
    if ([self typeFlags] & kLGToolTypeAutoPkgSharedProcessor) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)defaultRepository
{
    if ([self typeFlags] & kLGToolTypeAutoPkgSharedProcessor) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSString *)gitHubURL
{
    if ([[self class] typeFlags] & kLGToolTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

+ (NSArray *)packageIdentifiers
{
    if ([[self class] typeFlags] & kLGToolTypeInstalledPackage) {
        subclassMustImplement(self, _cmd);
    }
    return nil;
}

- (void)customInstallActions {}
- (void)customUninstallActions {}

#pragma mark - Super implementation
- (void)getInfo:(void (^)(LGToolInfo *))reply {

    void (^updateInfoHandlers)() = ^(){
        dispatch_async(autopkgr_tool_synchronizer_queue(), ^{
            if (reply || _infoUpdateHandler) {
                _info = [[LGToolInfo alloc] initWithTool:self];

                if (_infoUpdateHandler) {
                    _infoUpdateHandler(_info);
                }
                if (reply) {
                    reply(_info);
                }
            } else {
                _info = [[LGToolInfo alloc] initWithTool:self];
            }
        });
    };

    if (self.gitHubInfo.isExpired) {
        DevLog(@"Getting remote GitHub info for %@", NSStringFromClass([self class]));

        LGGitHubJSONLoader *loader = [[LGGitHubJSONLoader alloc] initWithGitHubURL:[[self class] gitHubURL]];

        [loader getReleaseInfo:^(LGGitHubReleaseInfo *gitHubInfo, NSError *error) {
            self.gitHubInfo = gitHubInfo;
            updateInfoHandlers();
        }];
    } else {
        DevLog(@"Using cached GitHub info for %@", NSStringFromClass([self class]));
        updateInfoHandlers();
    }
}

- (void)refresh;
{
    [self getInfo:nil];
}

- (LGToolInfo *)info
{
    if (!_info) {
        _info = [[LGToolInfo alloc] initWithTool:self];
    }
    return _info;
}

- (NSString *)remoteVersion
{
    if ([[self class] typeFlags] & kLGToolTypeInstalledPackage) {
        return self.gitHubInfo.latestVersion;
    }

    // For now shared processors don't report a version.
    // We could possibly use git to check for an update.
    return nil;
}

- (NSString *)installedVersion
{
    LGToolTypeFlags typeFlags = [[self class] typeFlags];

    if (typeFlags & kLGToolTypeInstalledPackage) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *packageReceipt = [[@"/private/var/db/receipts/" stringByAppendingPathComponent:[[[self class] packageIdentifiers] firstObject]] stringByAppendingPathExtension:@"plist"];

        if ([[self class] isInstalled]) {
            if ([fm fileExistsAtPath:packageReceipt]) {
                NSDictionary *receiptDict = [NSDictionary dictionaryWithContentsOfFile:packageReceipt];
                _installedVersion = receiptDict[@"PackageVersion"];
            }
        }
    } else if (typeFlags & kLGToolTypeAutoPkgSharedProcessor) {
        _installedVersion = @"Shared Processor";
    }

    return _installedVersion;
}

- (NSString *)downloadURL
{
    return self.gitHubInfo.latestReleaseDownload;
}

#pragma mark - Installer
- (void)install:(id)sender
{
    // Disable the sender to prevent multiple signals
    if ([sender respondsToSelector:@selector(isEnabled)]) {
        [sender setEnabled:NO];
    }

    LGToolTypeFlags flags = [[self class] typeFlags];

    if (flags & kLGToolTypeInstalledPackage) {
        [self installPackage:sender];
    } else if (flags & kLGToolTypeAutoPkgSharedProcessor) {
        [self installDefaultRepository:sender];
    }
}

- (void)installPackage:(id)sender
{
    NSString *name = [[self class] name];
    LGToolTypeFlags typeFlags = [[self class] typeFlags];

    NSString *installMessage = [NSString stringWithFormat:@"Installing %@...", [[self class] name]];
    [_progressDelegate startProgressWithMessage:installMessage];

    LGInstaller *installer = [[LGInstaller alloc] init];
    installer.downloadURL = self.downloadURL;
    installer.progressDelegate = self.progressDelegate;

    [installer runInstaller:name reply:^(NSError *error) {
        if (!error && (typeFlags & kLGToolTypeAutoPkgSharedProcessor)) {
            [self installDefaultRepository:sender];
        } else {
            [self didCompleteInstallAction:sender error:error];
        }
    }];
}

- (void)installDefaultRepository:(id)sender
{
    NSString *name = [[self class] name];

    LGAutoPkgTask *task = [LGAutoPkgTask repoAddTask:[[self class] defaultRepository]];

    if (_progressDelegate) {
        [_progressDelegate startProgressWithMessage:[NSString stringWithFormat:@"Adding default AutoPkg repo for %@", name]];

        task.progressDelegate = _progressDelegate;
    }

    [task launchInBackground:^(NSError *error) {
        [self didCompleteInstallAction:sender error:error];
    }];
}

- (void)install:(void (^)(NSString *, double))progress reply:(void (^)(NSError *))reply
{
    if (progress) {
        _progressUpdateBlock = progress;
        _progressDelegate = self;
    }

    if (reply) {
        _replyErrorBlock = reply;
    }

    [self install:nil];
}

#pragma mark - Uninstall
- (void)uninstall:(id)sender
{
    void (^removeRepo)() = ^void() {
        NSString *defaultRepo = [[self class] defaultRepository];
        if ([LGAutoPkgTask version] && [[LGAutoPkgTask repoList] containsObject:defaultRepo]) {
            LGAutoPkgTask *task = [LGAutoPkgTask repoDeleteTask:defaultRepo];
            if (_progressDelegate) {
                task.progressDelegate = _progressDelegate;
            }
            [task launchInBackground:^(NSError *error) {
                [self didCompleteInstallAction:sender error:error];
            }];
        } else {
            [self didCompleteInstallAction:sender error:nil];
        }
    };

    if ([[self class] isInstalled]) {
        LGToolTypeFlags flags = [[self class] typeFlags];

        if (flags & kLGToolTypeInstalledPackage) {
            LGUninstaller *uninstaller = [[LGUninstaller alloc] init];

            NSString *message = [NSString stringWithFormat:@"Uninstalling %@...", [[self class] name]];
            [_progressDelegate startProgressWithMessage:message];

            if (_progressDelegate) {
                uninstaller.progressDelegate = _progressDelegate;
            }

            [uninstaller uninstallPackagesWithIdentifiers:[[self class] packageIdentifiers] reply:^(NSError *error) {
                if (error || !(flags & kLGToolTypeAutoPkgSharedProcessor)) {
                    [self didCompleteInstallAction:sender error:error];
                } else {
                    removeRepo();
                }
            }];
        }
    }
}

- (void)uninstall:(void (^)(NSString *, double))progress reply:(void (^)(NSError *))reply
{
    _progressDelegate = self;
    if (progress) {
        _progressUpdateBlock = progress;
    }

    if (reply) {
        _replyErrorBlock = reply;
    }

    [self uninstall:nil];
}

#pragma mark - Install / Uninstall completion
- (void)didCompleteInstallAction:(id)sender error:(NSError *)error
{
    BOOL isInstalled = [[self class] isInstalled];
    if ([self.progressDelegate respondsToSelector:@selector(stopProgress:)]) {
        [self.progressDelegate stopProgress:error];
    }

    if ([sender respondsToSelector:@selector(isEnabled)]) {
        [sender setEnabled:YES];
    }

    if ([sender respondsToSelector:@selector(action)]) {
        [sender setAction:isInstalled ? @selector(uninstall:) : @selector(install:)];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationToolStatusDidChange object:self];

    [self refresh];
}

#pragma mark - Util

- (NSString *)versionTaskWithExec:(NSString *)exec arguments:(NSArray *)arguments
{
    NSString *installedVersion = nil;

    if ([[NSFileManager defaultManager] isExecutableFileAtPath:exec]) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = exec;
        task.arguments = arguments;
        task.standardOutput = [NSPipe pipe];

        [task launch];
        [task waitUntilExit];

        NSData *data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        if (data) {
            installedVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
    }

    return installedVersion ?: @"";
}

- (NSError *)requirementsError:(NSString *)reason
{
    NSString *description = [NSString stringWithFormat:@"Requirements for %@ are not met.", [[self class] name]];
    NSDictionary *userInfo = @{
        NSLocalizedDescriptionKey : description,
        NSLocalizedRecoverySuggestionErrorKey : reason ?: @"",
    };

    return [NSError errorWithDomain:kLGApplicationName code:-1 userInfo:userInfo];
}

#pragma mark - LGProgress Delegate

- (void)stopProgress:(NSError *)error
{
    if (_replyErrorBlock) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _replyErrorBlock(error);
        }];
    }
}

- (void)updateProgress:(NSString *)message progress:(double)progress
{
    if (_progressUpdateBlock) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            _progressUpdateBlock(message, progress);
        }];
    }
}

- (void)startProgressWithMessage:(NSString *)message { /* Not implemented */}
- (void)bringAutoPkgrToFront { /* Not implemented */}

@end

#pragma mark - Tool Info Object
@implementation LGToolInfo {
    NSString *_name;
    LGToolTypeFlags _typeFlags;

    LGToolInstallStatus _status;
    BOOL _installed;
    NSString *_defaultRepo;
}

- (instancetype)initWithTool:(LGTool *)tool;
{
    if (self = [super init]) {
        _name = [[tool class] name];
        _typeFlags = [[tool class] typeFlags];
        _installed = [[tool class] isInstalled];
        _defaultRepo = [[tool class] defaultRepository];

        _remoteVersion = tool.remoteVersion;
        _installedVersion = tool.installedVersion;
    }

    return self;
}

- (LGToolInstallStatus)status
{
    _status = kLGToolUpToDate;

    if (!_installed || !_installedVersion) {
        _status = kLGToolNotInstalled;
    } else if (_installedVersion && _remoteVersion) {
        if ([_remoteVersion version_isGreaterThan:_installedVersion]) {
            _status = kLGToolUpdateAvailable;
        }
    }
    return _status;
}

#pragma mark - Mappings

- (NSImage *)statusImage
{
    NSImage *stausImage = nil;
    switch (self.status) {
    case kLGToolNotInstalled:
        stausImage = [NSImage LGStatusNotInstalled];
        break;
    case kLGToolUpdateAvailable:
        stausImage = [NSImage LGStatusUpdateAvailable];
        break;
    case kLGToolUpToDate:
    default:
        stausImage = [NSImage LGStatusUpToDate];
        break;
    }
    return stausImage;
}

- (NSString *)statusString
{
    NSString *statusString = @"";
    switch (self.status) {
    case kLGToolNotInstalled:
        statusString = [NSString stringWithFormat:@"%@ not installed.", _name];
        break;
    case kLGToolUpdateAvailable:
        statusString = [NSString stringWithFormat:@"%@ %@ update now available.", _name, self.remoteVersion];
        break;
    case kLGToolUpToDate:
    default:
        statusString = [NSString stringWithFormat:@"%@ %@ installed.", _name, self.installedVersion];
        break;
    }
    return statusString;
}

- (NSString *)installButtonTitle
{
    NSString *title;
    switch (self.status) {
    case kLGToolUpToDate:
        if (_typeFlags & kLGToolTypeUninstallableTool) {
            title = @"Uninstall ";
            break;
        }
    case kLGToolNotInstalled:
        title = @"Install ";
        break;
    case kLGToolUpdateAvailable:
        title = @"Update ";
        break;
    default:
        title = @"";
        break;
    }
    return [title stringByAppendingString:_name];
}

- (BOOL)installButtonEnabled {
    switch (self.status) {
        case kLGToolNotInstalled: {}
        case kLGToolUpdateAvailable: {
            return YES;
        }
        case kLGToolUpToDate: {
            return (_typeFlags & kLGToolTypeUninstallableTool);
        }
        default: {
            break;
        }
    }
}

- (BOOL)needsInstalled
{
    switch (self.status) {
    case kLGToolNotInstalled:
    case kLGToolUpdateAvailable:
        return YES;
    case kLGToolUpToDate:
    default:
        return NO;
    }
}

- (SEL)targetAction
{
    if ((self.status == kLGToolUpToDate) && (_typeFlags | kLGToolTypeUninstallableTool)) {
        return @selector(uninstall:);
    } else {
        return @selector(install:);
    }
}

@end
