//
//  LGAutoPkgTask.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 8/30/14.
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import "LGAutoPkgTask.h"
#import "LGAutoPkgErrorHandler.h"
#import "LGAutoPkgResultHandler.h"
#import "LGHostInfo.h"
#import "LGVersioner.h"

#import "NSData+taskData.h"

#import <AHProxySettings/AHProxySettings.h>
#import <AFNetworking/AFNetworking.h>

#if DEBUG
/* For development using a custom version of autopkg, create
 * a symlink from the autopkg binary to /usr/local/bin/autopkg_dev
 * and set as AUTOPKG_DEV_MODE 1
 */
#define AUTOPKG_DEV_MODE 0
#endif

static NSString *const autopkg()
{
#if AUTOPKG_DEV_MODE
    DevLog(@"Using development autopkg binary");
    return @"/usr/local/bin/autopkg_dev";
#endif
    return @"/usr/local/bin/autopkg";
}

static NSString *const kLGAutoPkgTaskLock = @"com.lindegroup.autopkg.task.lock";
static NSString *const AUTOPKG_GITHUB_API_TOKEN_FILE = @"~/.autopkg_gh_token";

// Version Strings
static NSString *const AUTOPKG_0_3_0 = @"0.3.0";
static NSString *const AUTOPKG_0_3_1 = @"0.3.1";
static NSString *const AUTOPKG_0_3_2 = @"0.3.2";
static NSString *const AUTOPKG_0_4_0 = @"0.4.0";
static NSString *const AUTOPKG_0_4_1 = @"0.4.1";
static NSString *const AUTOPKG_0_4_2 = @"0.4.2";
static NSString *const AUTOPKG_0_4_3 = @"0.4.3";

// Autopkg Task Result keys
NSString *const kLGAutoPkgRecipeNameKey = @"Name";
NSString *const kLGAutoPkgRecipeIdentifierKey = @"Identifier";
NSString *const kLGAutoPkgRecipeDescriptionKey = @"Description";
NSString *const kLGAutoPkgRecipeInputKey = @"Input";
NSString *const kLGAutoPkgRecipeMinimumVersionKey = @"MinimumVersion";
NSString *const kLGAutoPkgRecipeParentKey = @"ParentRecipe";
NSString *const kLGAutoPkgRecipeProcessKey = @"Process";
NSString *const kLGAutoPkgRecipePathKey = @"Path";

NSString *const kLGAutoPkgRepoNameKey = @"RepoName";
NSString *const kLGAutoPkgRepoPathKey = @"RepoPath";
NSString *const kLGAutoPkgRepoURLKey = @"RepoURL";

// Reply blocks
typedef void (^AutoPkgReplyResultsBlock)(NSArray *results, NSError *error);
typedef void (^AutoPkgReplyReportBlock)(NSDictionary *report, NSError *error);
typedef void (^AutoPkgReplyErrorBlock)(NSError *error);

#pragma mark - AutoPkg Task (Internal Extensions)
@interface LGAutoPkgTask ()

@property (nonatomic, assign) LGAutoPkgVerb verb;
@property (strong, atomic) NSTask *task;
@property (strong, atomic) NSMutableArray *internalArgs;
@property (strong, atomic) NSMutableDictionary *internalEnvironment;

// Raw stdout/stderr strings and data
@property (copy, nonatomic, readwrite) NSMutableData *standardOutData;
@property (copy, nonatomic, readwrite) NSString *standardOutString;
@property (copy, nonatomic, readwrite) NSString *standardErrString;

// Handlers
@property (strong, nonatomic) LGAutoPkgErrorHandler *errorHandler;
@property (strong, nonatomic) LGVersioner *versioner;

// Results objects
@property (copy, nonatomic) NSString *reportPlistFile;
@property (copy, nonatomic) NSDictionary *report;
@property (copy, nonatomic, readwrite) id results;
@property (strong, nonatomic) NSError *error;

// Version
@property (copy, nonatomic) NSString *version;

@property (readwrite, nonatomic, strong) NSRecursiveLock *taskLock;

// Reply blocks
@property (copy, nonatomic, readwrite) AutoPkgReplyResultsBlock replyResultsBlock;
@property (copy, nonatomic, readwrite) AutoPkgReplyReportBlock replyReportBlock;
@property (copy, nonatomic, readwrite) AutoPkgReplyErrorBlock replyErrorBlock;

- (NSString *)taskDescription;
@end

#pragma mark - Task Manager
@implementation LGAutoPkgTaskManager

- (void)addOperation:(LGAutoPkgTask *)op
{
    [super addOperation:op];
    if (!op.progressDelegate && _progressDelegate) {
        op.progressDelegate = _progressDelegate;
    }

    if (!op.progressUpdateBlock && _progressUpdateBlock) {
        op.progressUpdateBlock = _progressUpdateBlock;
    }

    if (!op.replyErrorBlock && _errorBlock) {
        op.replyErrorBlock = _errorBlock;
    }
}

- (void)addOperationAndWait:(LGAutoPkgTask *)op
{
    [self addOperation:op];
    [op waitUntilFinished];
}

- (void)addOperations:(NSArray *)ops waitUntilFinished:(BOOL)wait
{
    NSPredicate *classPredicate = [NSPredicate predicateWithFormat:@"SELF isKindOfClass: %@", [LGAutoPkgTask class]];
    NSArray *validObjects = [ops filteredArrayUsingPredicate:classPredicate];
    for (LGAutoPkgTask *op in validObjects) {
        if (!op.progressDelegate && _progressDelegate) {
            op.progressDelegate = _progressDelegate;
        }
    }
    [super addOperations:validObjects waitUntilFinished:wait];
}

- (void)cancel
{
    [self cancelAllOperations];
}

#pragma mark - Convenience Instance Methods
- (void)runRecipes:(NSArray *)recipes
             reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipesTask:recipes];
    task.replyReportBlock = reply;
    [self addOperation:task];
}

- (void)runRecipes:(NSArray *)recipes
    withInteraction:(BOOL)withInteraction
              reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipesTask:recipes];
    task.replyReportBlock = reply;
    [self addOperation:task];
}

- (void)runRecipeList:(NSString *)recipeList
           updateRepo:(BOOL)updateRepo
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *runTask = [LGAutoPkgTask runRecipeListTask:recipeList];
    runTask.replyReportBlock = reply;

    if (updateRepo) {
        LGAutoPkgTask *repoUpdate = [LGAutoPkgTask repoUpdateTask];
        [runTask addDependency:repoUpdate];
        [self addOperation:repoUpdate];
    }

    [self addOperation:runTask];
}

- (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask searchTask:recipe];
    task.replyResultsBlock = reply;
    [self addOperation:task];
}

- (void)repoUpdate:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask repoUpdateTask];
    task.replyErrorBlock = reply;
    [self addOperation:task];
}

@end

#pragma mark - AutoPkg Task
@implementation LGAutoPkgTask {
    BOOL _isExecuting;
    BOOL _isFinished;
    BOOL _userCanceled;
}

- (NSString *)taskDescription
{
    return [NSString stringWithFormat:@"%@ %@", self.task.launchPath, [self.task.arguments componentsJoinedByString:@" "]];
}

- (void)dealloc
{
    DLog(@"Completed AutoPkg Task:\n  %@\n", [self taskDescription]);
    self.replyErrorBlock = nil;
    self.replyReportBlock = nil;
    self.replyResultsBlock = nil;
}

- (id)init
{
    if (self = [super init]) {
        _internalArgs = [@[ autopkg() ] mutableCopy];
        _taskLock = [[NSRecursiveLock alloc] init];
        _taskLock.name = kLGAutoPkgTaskLock;
        _taskStatusDelegate = self;
        _isExecuting = NO;
        _isFinished = NO;
        _version = [[self class] version];
    }
    return self;
}

- (instancetype)initWithArguments:(NSArray *)arguments
{
    self = [self init];
    if (self) {
        self.arguments = arguments;
    }
    return self;
}

#pragma mark - NSOperation Overrides
- (void)start
{
    if ([self isCancelled]) {
        // Must move the operation to the finished state if it is canceled.
        return [self setIsFinished:YES];
    }

    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];

    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)cancel
{
    [self.taskLock lock];

    _userCanceled = YES;
    if (self.task && self.task.isRunning) {
        DLog(@"Canceling %@", self.taskDescription);
        [self.task terminate];
    } else if (_taskStatusDelegate) {
        [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didCompleteOperation:) withObject:nil waitUntilDone:NO];
    }
    [self.taskLock unlock];
    [super cancel];
}

- (void)main
{
    @autoreleasepool
    {
        self.task = [[NSTask alloc] init];
        self.task.launchPath = @"/usr/bin/python";

        assert(_internalArgs.count);
        assert(_arguments.count);
        assert(_verb);
        assert(_version);

        self.task.arguments = [self.internalArgs copy];

        self.task.currentDirectoryPath = NSTemporaryDirectory();

        // If an instance of autopkg is running,
        // and we're trying to do a run, exit.
        if (_verb == kLGAutoPkgRun && [[self class] instanceIsRunning]) {
            self.error = [LGError errorWithCode:kLGErrorMultipleRunsOfAutopkg];
            [self didCompleteTaskExecution];
            return;
        }

        [self configureFileHandles];
        [self configureEnvironment];

        if (self.internalEnvironment) {
            self.task.environment = [self.internalEnvironment copy];
        }

        __weak typeof(self) weakSelf = self;
        [self.task setTerminationHandler:^(NSTask *task) {
            [weakSelf didCompleteTaskExecution];
        }];

        // Since NSTask can raise for unexpected reasons,
        // put it in a try-catch block
        @try {
            [self.task launch];
        }
        @catch (NSException *exception)
        {
            NSString *message = LGAutoPkgLocalizedString(@"A fatal error occurred when trying to run AutoPkg", nil);

            NSString *suggestion = LGAutoPkgLocalizedString( @"If you repeatedly see this message please report it. The full scope of the error is in the system.log, make sure to include that in the report", nil);

            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : message,
                                        NSLocalizedRecoverySuggestionErrorKey : suggestion};

            NSLog(@"[AutoPkgr EXCEPTION] %@ %@", exception.reason, exception.userInfo);

            self.error = [NSError errorWithDomain:kLGApplicationName code:-9 userInfo:userInfo];
            [self didCompleteTaskExecution];
        }
    }
}

#pragma mark
- (BOOL)isExecuting
{
    return _isExecuting || self.task.isRunning;
}

- (void)setIsExecuting:(BOOL)isExecuting
{
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isFinished
{
    return _isFinished && !self.task.isRunning;
}

- (void)setIsFinished:(BOOL)isFinished
{
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

#pragma mark
- (void)didCompleteTaskExecution
{
    if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
        [self.task.standardOutput fileHandleForReading].readabilityHandler = nil;
    }

    if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
        [self.task.standardError fileHandleForReading].readabilityHandler = nil;
    }

    if (!_error && !_userCanceled) {
        [self.taskLock lock];
        self.error = [_errorHandler errorWithExitCode:self.task.terminationStatus];
        [self.taskLock unlock];
    }

    if (_verb & (kLGAutoPkgRepoAdd | kLGAutoPkgRepoDelete | kLGAutoPkgRepoUpdate)) {
        // Post a notification for objects watching for modified repos.
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kLGNotificationReposModified object:nil];
        });
    }

    LGAutoPkgTaskResponseObject *response = [[LGAutoPkgTaskResponseObject alloc] init];
    response.results = self.results;
    response.report = self.report;
    response.error = self.error;

    [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didCompleteOperation:) withObject:response waitUntilDone:NO];

    [self setIsExecuting:NO];
    [self setIsFinished:YES];

    self.task.terminationHandler = nil;
}

#pragma mark - Convenience Initializers
- (void)launch
{
    LGAutoPkgTaskManager *mgr = [[LGAutoPkgTaskManager alloc] init];
    //    NSAssert([self isInteractiveOperation], @"[autopkg %@] Interactive commands must be launched asynchronously. Use launchInBackground:", self.internalArgs.firstObject);

    [mgr addOperationAndWait:self];
}

- (void)launchInBackground:(void (^)(NSError *))reply
{
    LGAutoPkgTaskManager *bgQueue = [LGAutoPkgTaskManager new];
    self.replyErrorBlock = reply;
    [bgQueue addOperation:self];
}

#pragma mark - Accessors
- (void)setArguments:(NSArray *)arguments
{
    [self.taskLock lock];
    /** _arguments is the externally set values
     * _internalArguments is the mutable array that has
     *  the path to autopkg set as the first object during init
     */
    _arguments = arguments;
    if (arguments.count) {
        [self.internalArgs addObjectsFromArray:arguments];
    }

    NSString *verbString = [_arguments firstObject];
    if ([verbString isEqualToString:@"version"]) {
        _verb = kLGAutoPkgVersion;
    } else if ([verbString isEqualToString:@"run"]) {
        _verb = kLGAutoPkgRun;
        if (([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_4_0])) {
            [self.internalArgs addObject:self.reportPlistFile];
        }
        [self.internalArgs addObject:@"-v"];
    } else if ([verbString isEqualToString:@"list-recipes"]) {
        _verb = kLGAutoPkgListRecipes;
    } else if ([verbString isEqualToString:@"make-override"]) {
        _verb = kLGAutoPkgMakeOverride;
    } else if ([verbString isEqualToString:@"search"]) {
        _verb = kLGAutoPkgSearch;
        // If the api token file exists update the args.
        if ([[self class] apiTokenFileExists:nil]) {
            [self.internalArgs addObject:@"-t"];
        }
    } else if ([verbString isEqualToString:@"info"]) {
        _verb = kLGAutoPkgInfo;
    } else if ([verbString isEqualToString:@"repo-add"]) {
        _verb = kLGAutoPkgRepoAdd;
    } else if ([verbString isEqualToString:@"repo-delete"]) {
        _verb = kLGAutoPkgRepoDelete;
    } else if ([verbString isEqualToString:@"repo-update"]) {
        _verb = kLGAutoPkgRepoUpdate;
    } else if ([verbString isEqualToString:@"repo-list"]) {
        _verb = kLGAutoPkgRepoList;
    } else if ([verbString isEqualToString:@"list-processors"]) {
        _verb = kLGAutoPkgListProcessors;
    } else if ([verbString isEqualToString:@"processor-info"]) {
        _verb = kLGAutoPkgProcessorInfo;
    }

    [self.taskLock unlock];
}

- (NSString *)version
{
    if (!_version) {
        _version = [[self class] version];
    }
    return _version;
}

#pragma mark - Task config helpers
- (void)configureFileHandles
{
    // Place holder for stdin
    NSPipe *standardInput;

    // Set up stdout
    NSPipe *standardOutput = [NSPipe pipe];
    self.task.standardOutput = standardOutput;

    // Set up stderr
    // The Error handler class creates a the pipe to process the stderr messages.
    _errorHandler = [[LGAutoPkgErrorHandler alloc] initWithVerb:_verb];
    self.task.standardError = _errorHandler.pipe;

    BOOL isInteractive = [self isInteractiveOperation];
    if (isInteractive) {
        /* As of AutoPkg 0.4.3 there is an interactive search feature
         * so setup stdin */
        standardInput = [NSPipe pipe];
        self.task.standardInput = standardInput;
    }

    if (_verb & (kLGAutoPkgRun | kLGAutoPkgRepoUpdate)) {

        if (([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_4_0])) {
            /* As of 0.4.0 AutoPkg saves the report.plist to a file rather than stdout,
             * so we can send progress messages */

            __block double count = 0.0;
            __block double total;
            NSPredicate *progressPredicate;

            if (_verb == kLGAutoPkgRun) {
                _versioner = [[LGVersioner alloc] init];
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES '^Processing.*\\.\\.\\.'"];

                total = [self recipeListCount];
            } else if (_verb == kLGAutoPkgRepoUpdate) {
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.git'"];
                total = [[[self class] repoList] count];
            }

            BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"verboseAutoPkgRun"];
            [[standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
                NSData *data = handle.availableData;

                if (data.length) {
                    NSString *message = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];

                    if (isInteractive && data.taskData_isInteractive) {
                        DevLog(@"Prompting for interaction: %@", message);
                        return [self interactiveAlertWithMessage:message];
                    }

                    [_versioner parseString:message];
                    if ([progressPredicate evaluateWithObject:message]) {
                        NSString *fullMessage;
                        if (_verb == kLGAutoPkgRepoUpdate) {
                            fullMessage = [NSString stringWithFormat:@"Updating %@", [message lastPathComponent]];
                        } else {
                            int cntStr = (int)round(count) + 1;
                            int totStr = (int)round(total);
                            fullMessage = [[NSString stringWithFormat:@"(%d/%d) %@", cntStr, totStr, message] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                        }

                        double progress = ((count/total) * 100);

                        LGAutoPkgTaskResponseObject *response = [[LGAutoPkgTaskResponseObject alloc] init];
                        response.progressMessage = fullMessage;
                        response.progress = progress;
                        count++;

                        [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didReceiveStatusUpdate:) withObject:response waitUntilDone:NO];

                        // If verboseAutoPkgRun is not enabled, log the limited message here.
                        if (!verbose) {
                            NSLog(@"%@",message);
                        }
                    }
                    // If verboseAutoPkgRun is enabled, log everything generated by autopkg run -v.
                    if (verbose) {
                        NSLog(@"%@",message);
                    }
                }
            }];
        }
    } else {
        // In order to prevent maxing out the stdout buffer collect the data progressively
        // even thought the data returned is usually small.
        [[standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
            NSData *data = [fh availableData];
            if (data.length) {
                if (isInteractive && data.taskData_isInteractive) {
                    return [self interactiveAlertWithMessage:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
                }

                if (!_standardOutData) {
                    _standardOutData = [[NSMutableData alloc] init ];
                }
                [_standardOutData appendData:data];
            }
        }];
    }
}

- (void)configureEnvironment
{
    // If the task is a network operation set proxies
    if ([self isNetworkOperation]) {

        LGDefaults *defaults = [[LGDefaults alloc] init];

        if ([defaults boolForKey:@"useSystemProxies"]) {
            AHProxySettings *settings = [[AHProxySettings alloc] initWithDestination:@"https://github.com"];
            if (settings.taskDictionary) {
                DLog(@"Using System Proxies: %@", settings.taskDictionary);
                // This will just initialize the _internalEnvironment
                [self addEnvironmentVariable:nil forKey:nil];
                [_internalEnvironment addEntriesFromDictionary:settings.taskDictionary];
            }
        } else {

            NSString *httpProxy = [defaults objectForKey:@"HTTP_PROXY"];
            NSString *httpsProxy = [defaults objectForKey:@"HTTPS_PROXY"];
            NSString *noProxy = [defaults objectForKey:@"NO_PROXY"];

            if (httpProxy) {
                [self addEnvironmentVariable:httpProxy forKey:@"HTTP_PROXY"];
                DLog(@"Using HTTP_PROXY: %@", httpProxy);
            }

            if (httpsProxy) {
                [self addEnvironmentVariable:httpsProxy forKey:@"HTTPS_PROXY"];
                DLog(@"Using HTTPS_PROXY: %@", httpsProxy);
            }
            if (noProxy) {
                [self addEnvironmentVariable:noProxy forKey:@"NO_PROXY"];
                DLog(@"Using NO_PROXY (Exception List): %@", noProxy);
            }
        }
    }

    if (_verb & (kLGAutoPkgRun | kLGAutoPkgRepoUpdate)) {
        // To get status from autopkg set NSUnbufferedIO environment key to YES
        // Thanks to help from -- http://stackoverflow.com/questions/8251010
        [self addEnvironmentVariable:@"YES" forKey:@"NSUnbufferedIO"];
    }
}

- (void)addEnvironmentVariable:(NSString *)variable forKey:(NSString *)key
{
    if (!_internalEnvironment) {
        _internalEnvironment = [[[NSProcessInfo processInfo] environment] mutableCopy];
    }
    if (variable && key) {
        [_internalEnvironment setObject:variable forKey:key];
    }
}

#pragma mark - Output / Results
- (int)exitCode
{
    if (!self.task.isRunning) {
        return self.task.terminationStatus;
    }

    return NSTaskTerminationReasonUncaughtSignal;
}

- (NSString *)standardErrString
{
    [self.taskLock lock];
    if (!_standardErrString && !self.task.isRunning) {
        _standardErrString = _errorHandler.errorString;
    }

    [self.taskLock unlock];
    return _standardErrString;
}

- (NSString *)standardOutString
{
    [self.taskLock lock];
    if (!_standardOutString && !self.task.isRunning) {
        NSData *data;
        if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
            // If standardOutData exists then the sdtout was gathered progressively
            if (self.standardOutData) {
                data = [self.standardOutData copy];
            } else {
                data = [[self.task.standardOutput fileHandleForReading] readDataToEndOfFile];
            }
            if (data) {
                _standardOutString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }
        }
    }
    [self.taskLock unlock];
    return _standardOutString;
}

- (NSDictionary *)report
{
    if (_report || _verb != kLGAutoPkgRun) {
        return _report;
    }

    [[LGDefaults standardUserDefaults] setLastAutoPkgRun:[NSDate date]];

    NSMutableDictionary *workingReport;

    if (([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_4_0])) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *reportPlistFile = self.reportPlistFile;

        if (reportPlistFile && [fm fileExistsAtPath:reportPlistFile]) {
            // Create dictionary from the tmp file
            workingReport = [NSMutableDictionary dictionaryWithContentsOfFile:reportPlistFile];

            // Cleanup the tmp file (unless debugging is enabled)
            if (![[LGDefaults standardUserDefaults] debug]) {
                NSError *error;
                if (![fm removeItemAtPath:reportPlistFile error:&error]) {
                    DLog(@"Error removing autopkg run report-plist: %@", error.localizedDescription);
                }
            }
        }
    } else {
        // For AutoPkg earlier than 0.4.0 the report plist was piped to stdout
        // so convert that string to an NSDictionary
        workingReport = [[self serializePropertyListString:self.standardOutString] mutableCopy];
    }

    [workingReport setObject:_version forKey:@"report_version"];

    NSArray *versionerResults = _versioner.currentResults;
    if (versionerResults) {
        [workingReport setObject:versionerResults forKey:@"detected_versions"];
    }

    _report = [workingReport copy];
    return _report;
}

- (NSString *)reportPlistFile
{
    if (!_reportPlistFile) {
        NSString *reportSubfolder = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
        NSFileManager *mgr = [NSFileManager defaultManager];
        BOOL isDir;
        if (![mgr fileExistsAtPath:reportSubfolder isDirectory:&isDir] || !isDir) {
            if (!isDir) {
                [mgr removeItemAtPath:reportSubfolder error:nil];
            }
            [mgr createDirectoryAtPath:reportSubfolder withIntermediateDirectories:YES attributes:nil error:nil];
        }
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"YYYYMMddHHmmss"];
        _reportPlistFile = [reportSubfolder stringByAppendingPathComponent:[formatter stringFromDate:[NSDate date]]];
    }
    return _reportPlistFile;
}

- (NSArray *)results
{
    if (!_results) {
        [self.taskLock lock];
        if (!self.task.isRunning) {
            NSData *data;
            if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
                data = [[self.task.standardOutput fileHandleForReading] readDataToEndOfFile];

                // If standardOutData exists then the sdtout was gathered progressively
                if (self.standardOutData) {
                    [self.standardOutData appendData:data];
                    data = [self.standardOutData copy];
                }
            }
            LGAutoPkgResultHandler *resultHandler = [[LGAutoPkgResultHandler alloc] initWithData:data verb:_verb];
            _results = resultHandler.results;
        }

        [self.taskLock unlock];
    }
    return _results;
}

#pragma mark - Utility
- (BOOL)isNetworkOperation
{
    return (_verb & (kLGAutoPkgRun | kLGAutoPkgSearch | kLGAutoPkgRepoAdd | kLGAutoPkgRepoUpdate));
}

- (BOOL)isInteractiveOperation
{
    return (_verb & (kLGAutoPkgRun | kLGAutoPkgInfo)) && [_version version_isGreaterThanOrEqualTo:AUTOPKG_0_4_3];
}

- (NSInteger)recipeListCount
{
    NSInteger count = 0;
    if (_verb == kLGAutoPkgRun) {
        NSString *file = [_arguments objectAtIndex:2];
        if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
            NSString *fileContents = [NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil];
            count = [[fileContents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] count];
        }
    }
    return count;
}

- (id)serializePropertyListString:(NSString *)string
{
    id results = nil;
    if (string.length) {
        NSData *plistData = [string dataUsingEncoding:NSUTF8StringEncoding];
        // Initialize our dict
        results = [NSPropertyListSerialization propertyListWithData:plistData
                                                            options:NSPropertyListImmutable
                                                             format:nil
                                                              error:nil];
    }
    return results;
}

- (void)interactiveAlertWithMessage:(NSString *)message
{
    /* Eventually there may be more ways to interact, for now it's only to search github for a recipe's repo */
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSString *title = LGAutoPkgLocalizedString(@"Could not find the parent recipe"
                                                     , nil);

        NSString *cleanedMessage = [message stringByReplacingOccurrencesOfString:@"[y/n]:"
                                                                      withString:@""];
        NSAlert *alert = [NSAlert alertWithMessageText:title
                                         defaultButton:@"Yes"
                                       alternateButton:@"No"
                                           otherButton:nil
                             informativeTextWithFormat:@"%@", cleanedMessage];

        NSString *results;
        // Don't forget the newline char!
        if ([alert runModal] == NSAlertDefaultReturn) {
            results = @"y\n";
        } else {
            results = @"n\n";
        }

        [[self.task.standardInput fileHandleForWriting] writeData:[results dataUsingEncoding:NSUTF8StringEncoding]];
    }];
}

#pragma mark - Class Methods
#pragma mark-- Recipe Methods --
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *, double))progress
             reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipesTask:recipes];
    task.progressUpdateBlock = progress;

    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask:recipeList];
    task.progressUpdateBlock = progress;

    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask searchTask:recipe];
    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        NSArray *results;
        if (!error) {
            results = [weakTask results];
        }
        reply(results, error);
    }];
}

+ (void)makeOverride:(NSString *)recipe reply:(void (^)(NSString *, NSError *))reply
{
    [[self class] makeOverride:recipe name:nil reply:reply];
}

+ (void)makeOverride:(NSString *)recipe name:(NSString *)name reply:(void (^)(NSString *, NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    NSMutableArray *args = [@[ @"make-override", recipe ] mutableCopy];
    if (name.length) {
        [args addObjectsFromArray:@[ @"-n", name ]];
    }

    task.arguments = args;
    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        typeof(task) strongTask = weakTask;
        NSMutableString *path = nil;
        if(!error){
            path = [strongTask.standardOutString.trimmed mutableCopy];
            [path deleteCharactersInRange:[path rangeOfString:@"Override file saved to "]];
            if ((path.length > 2) && ([path characterAtIndex:path.length-1] == '.')) {
                [path deleteCharactersInRange:NSMakeRange(path.length-1, 1)];
            }
        }

        reply(path, error);
    }];
}

+ (NSArray *)listRecipes
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"list-recipes" ]];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

+ (void)info:(NSString *)recipe reply:(void (^)(NSString *info, NSError *error))reply;
{
    NSParameterAssert(recipe);

    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"info", recipe ]];
    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        typeof(task) strongTask = weakTask;
        reply(strongTask.standardOutString, error);
    }];
}

#pragma mark-- Repo Methods --
+ (void)repoAdd:(NSString *)repo reply:(void (^)(NSError *))reply
{
    NSParameterAssert(repo);

    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    // Make sure everything that comes in has the .git extension.
    if (![repo.pathExtension isEqualToString:@"git"]) {
        repo = [repo stringByAppendingPathExtension:@"git"];
    }
    task.arguments = @[ @"repo-add", repo ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoRemove:(NSString *)repo reply:(void (^)(NSError *))reply
{
    NSParameterAssert(repo);
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-delete", repo ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoUpdate:(void (^)(NSString *, double taskProgress))progress
             reply:(void (^)(NSError *error))reply;
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-update", @"all" ]];
    task.progressUpdateBlock = progress;
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (NSArray *)repoList
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-list" ]];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

#pragma mark--Processor Methods--
+ (NSArray *)listProcessors
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"list-processors" ]];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

+ (NSString *)processorInfo:(NSString *)processor
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"processor-info", processor ]];
    [task launch];
    return task.standardOutString;
}

#pragma mark - Other
+ (NSString *)version
{
    NSString *version;

    NSTask *task = [[NSTask alloc] init];

    task = task;
    task.launchPath = @"/usr/bin/python";
    task.arguments = @[ autopkg(), @"version" ];
    task.standardOutput = [NSPipe pipe];
    [task launch];
    [task waitUntilExit];

    NSData *data = [[task.standardOutput fileHandleForReading] availableData];
    if (data.length) {
        version = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }

    return [version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] ?: @"0.0.0";
}

+ (NSString *)apiToken
{
    NSString *tokenFile = nil;
    if ([self apiTokenFileExists:&tokenFile]) {
        return [NSString stringWithContentsOfFile:tokenFile encoding:NSUTF8StringEncoding error:nil];
    }
    return nil;
}

+ (BOOL)apiTokenFileExists:(NSString *__autoreleasing *)file
{
    NSString *tokenFile = AUTOPKG_GITHUB_API_TOKEN_FILE.stringByExpandingTildeInPath;
    if (file)
        *file = tokenFile;
    return (access(tokenFile.UTF8String, R_OK) == 0);
}

+ (void)generateGitHubAPIToken:(NSString *)username password:(NSString *)password reply:(void (^)(NSError *))reply
{

    NSString *tokenFile = nil;
    if (![self apiTokenFileExists:&tokenFile]) {

        // Headers & Parameters
        NSDictionary *headers = @{
            @"Accept" : @"application/vnd.github.v3+json",
            @"User-Agent" : @"AutoPkg",
        };

        NSDictionary *parameters = @{ @"note" : @"AutoPkg CLI" };

        // Networking
        AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.github.com"]];

        // Request Serializer
        manager.requestSerializer = [AFJSONRequestSerializer serializer];
        [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:username password:password];
        [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
        }];

        // Response serializer
        manager.responseSerializer = [AFJSONResponseSerializer serializer];

        [manager POST:@"/authorizations" parameters:parameters success:^(AFHTTPRequestOperation *operation, NSDictionary *responseObject) {
            NSError *error = nil;
            NSString *tokenString = responseObject[@"token"];

            if (tokenString.length){
                [tokenString writeToFile:tokenFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
                reply(error);
            } else {
                reply(error);
            }
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
        }];
    } else {
        reply(nil);
    }
}

+ (void)deleteGitHubAPIToken:(NSString *)username password:(NSString *)password reply:(void (^)(NSError *))reply
{
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.github.com"]];

    // Request Serializer
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:username
                                                              password:password];

    [manager GET:@"/authorizations" parameters:nil success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
        // Get Auth ID
        __block NSDictionary *autoPkgTokenDict = nil;
        NSString *token = [self apiToken];
        NSString *tokenLastEight = [token substringFromIndex:token.length - 8];

        [responseObject enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
            if ([@"AutoPkg CLI" isEqualToString:obj[@"note"]] &&
                 [tokenLastEight isEqualToString:obj[@"token_last_eight"]]) {
                autoPkgTokenDict = obj;
                *stop = YES;
            }
        }];

        if (autoPkgTokenDict) {
            NSString *delete = [NSString stringWithFormat:@"/authorizations/%@", autoPkgTokenDict[@"id"]];

            /* Delete the token from the remote */
            [manager DELETE:delete parameters:@{} success:^(AFHTTPRequestOperation *operation, id responseObject) {
                // remove the file
                NSString *tokenFile = nil;
                NSError *error = nil;
                if ([self apiTokenFileExists:&tokenFile]) {
                    [[NSFileManager defaultManager] removeItemAtPath:tokenFile error:&error];
                }
                reply(error);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
            }];
        } else {
            NSString *message = LGAutoPkgLocalizedString(@"API Token not found.", nil);
            NSString *suggestion =  LGAutoPkgLocalizedString(@"A GitHub API token matching the local one was not found on the remote. You may need to remove it manually. If you've just added the token, you may need to wait a minute to delete it.", nil);

            NSError *error = [NSError errorWithDomain:[[NSProcessInfo processInfo] processName]
                                                 code:-2
                                             userInfo:@{NSLocalizedDescriptionKey : message,
                                                        NSLocalizedRecoverySuggestionErrorKey : suggestion}];
            reply(error);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
    }];
}

#pragma mark-- Convenience Initializers --
+ (LGAutoPkgTask *)runRecipesTask:(NSArray *)recipes
{
    return [self runRecipesTask:recipes withInteraction:NO];
}

+ (LGAutoPkgTask *)runRecipesTask:(NSArray *)recipes withInteraction:(BOOL)withInteraction
{
    LGAutoPkgTask *task = nil;
    if (recipes.count) {
        NSMutableArray *fullRecipes = [NSMutableArray arrayWithObject:@"run"];
        [fullRecipes addObjectsFromArray:recipes];
        [fullRecipes addObject:@"--report-plist"];

        task = [[LGAutoPkgTask alloc] initWithArguments:[fullRecipes copy]];
    }

    return task;
}

+ (LGAutoPkgTask *)runRecipeListTask:(NSString *)recipeList
{
    NSParameterAssert(recipeList);
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"run", @"--recipe-list", recipeList, @"--report-plist" ];
    return task;
}

+ (LGAutoPkgTask *)searchTask:(NSString *)recipe
{
    NSParameterAssert(recipe);
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"search", recipe ]];
    return task;
}

+ (LGAutoPkgTask *)repoUpdateTask
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-update", @"all" ]];
    return task;
}

+ (LGAutoPkgTask *)repoAddTask:(NSString *)repo
{
    NSParameterAssert(repo);
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-add", repo ]];
    return task;
}

+ (LGAutoPkgTask *)repoDeleteTask:(NSString *)repo;
{
    NSParameterAssert(repo);
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-delete", repo ]];
    return task;
}

#pragma mark-- Other Methods --
+ (BOOL)instanceIsRunning
{
    NSArray *runningArgs = @[ autopkg(), @"run", @"--recipe-list" ];
    return ([BSDProcessInfo processWithName:@"Python"
                          matchingArguments:runningArgs] != nil);
}

#pragma mark - Task Status Update Delegate
- (void)didReceiveStatusUpdate:(LGAutoPkgTaskResponseObject *)object
{
    if (![NSThread isMainThread]) {
        [self performSelector:@selector(didReceiveStatusUpdate:) onThread:[NSThread mainThread] withObject:object waitUntilDone:NO];
        return;
    }

    if (object.progressMessage) {
        if (_progressUpdateBlock) {
            _progressUpdateBlock(object.progressMessage, object.progress);
        }

        if (_progressDelegate) {
            [_progressDelegate updateProgress:object.progressMessage progress:object.progress];
        }
    }
}

- (void)didCompleteOperation:(LGAutoPkgTaskResponseObject *)object
{
    if (![NSThread isMainThread]) {
        [self performSelector:@selector(didCompleteOperation:) onThread:[NSThread mainThread] withObject:object waitUntilDone:NO];
        return;
    }

    if (_replyResultsBlock) {
        _replyResultsBlock(object.results, object.error);
    }

    if (_replyReportBlock) {
        _replyReportBlock(object.report, object.error);
    }

    if (_replyErrorBlock) {
        _replyErrorBlock(object.error);
    }
}
@end

#pragma mark - Task Response Object
#pragma mark-- Secure Coding --
// Currently there is no need for this, but if we ever move the task over to an XPC bundle,
// we'll be able to pass this back and forth.
@implementation LGAutoPkgTaskResponseObject
+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super init];
    if (self) {
        self.progressMessage = [decoder decodeObjectOfClass:[NSString class]
                                                     forKey:NSStringFromSelector(@selector(progressMessage))];

        self.progress = [[decoder decodeObjectOfClass:[NSNumber class]
                                               forKey:NSStringFromSelector(@selector(progress))] doubleValue];

        self.results = [decoder decodeObjectOfClasses:[NSSet setWithArray:@[ [NSArray class],
                                                                             [NSDictionary class],
                                                                             [NSString class] ]]
                                               forKey:NSStringFromSelector(@selector(results))];

        self.report = [decoder decodeObjectOfClass:[NSDictionary class]
                                            forKey:NSStringFromSelector(@selector(report))];

        self.error = [decoder decodeObjectOfClass:[NSError class]
                                           forKey:NSStringFromSelector(@selector(error))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.progressMessage forKey:NSStringFromSelector(@selector(progressMessage))];
    [coder encodeDouble:self.progress forKey:NSStringFromSelector(@selector(progress))];
    [coder encodeObject:self.results forKey:NSStringFromSelector(@selector(results))];
    [coder encodeObject:self.report forKey:NSStringFromSelector(@selector(report))];
    [coder encodeObject:self.error forKey:NSStringFromSelector(@selector(error))];
}

@end
