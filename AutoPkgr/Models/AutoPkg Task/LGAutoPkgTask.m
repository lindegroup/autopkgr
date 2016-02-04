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
#import "LGTwoFactorAuthAlert.h"

#import "BSDProcessInfo.h"
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

static NSDictionary *AutoPkgVerbStringToEnum(){
    static dispatch_once_t onceToken;
    __strong static NSDictionary *verbDict = nil;
    dispatch_once(&onceToken, ^{
        verbDict = @{
                    @"run": @(kLGAutoPkgRun),
                    @"list-recipes": @(kLGAutoPkgListRecipes),
                    @"make-override": @(kLGAutoPkgMakeOverride),
                    @"search": @(kLGAutoPkgSearch),
                    @"info" : @(kLGAutoPkgInfo),
                    @"repo-add" : @(kLGAutoPkgRepoAdd),
                    @"repo-delete": @(kLGAutoPkgRepoDelete),
                    @"repo-update": @(kLGAutoPkgRepoUpdate),
                    @"repo-list": @(kLGAutoPkgRepoList),
                    @"processor-info": @(kLGAutoPkgProcessorInfo),
                    @"list-processors": @(kLGAutoPkgListProcessors),
                    @"version": @(kLGAutoPkgVersion),
                    };
    });
    return verbDict;
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
static NSString *const AUTOPKG_0_5_0 = @"0.5.0";
static NSString *const AUTOPKG_0_5_1 = @"0.5.1";
static NSString *const AUTOPKG_0_5_2 = @"0.5.2";


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


NSString *const kLGMunkiSetDefaultCatalogEnabledKey = @"MunkiSetDefaultCatalogPreProcessorEnabled";
NSString *const kLGPreProcessorDefaultsKey = @"PreProcessors";
NSString *const kLGPostProcessorDefaultsKey = @"PostProcessors";

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
        @catch (NSException *exception) {
            NSString *message = LGAutoPkgLocalizedString(@"A fatal error occurred when trying to run AutoPkg", nil);

            NSString *suggestion = LGAutoPkgLocalizedString(@"If you repeatedly see this message please report it. The full scope of the error is in the system.log, make sure to include that in the report", nil);

            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : message,
                                        NSLocalizedRecoverySuggestionErrorKey : suggestion };

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
    _verb = [AutoPkgVerbStringToEnum()[_arguments.firstObject] integerValue];
    if (_verb == kLGAutoPkgRun){
        _verb = kLGAutoPkgRun;
        if (([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_4_0])) {
            [self.internalArgs addObject:self.reportPlistFile];
        }
        [self.internalArgs addObject:@"-v"];

        [self configurePreProcessors];
        [self configurePostProcessors];
    } else if (_verb == kLGAutoPkgSearch){
        _verb = kLGAutoPkgSearch;
        // If the api token file exists update the args.
        if ([[self class] apiTokenFileExists:nil]) {
            [self.internalArgs addObject:@"-t"];
        }
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

    if (_verb & (kLGAutoPkgRun | kLGAutoPkgRepoUpdate | kLGAutoPkgRepoAdd)) {

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
            } else if (_verb == kLGAutoPkgRepoAdd){
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[CD] 'Attempting git'"];
                total = self.arguments.count - 1;
            }

            BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"verboseAutoPkgRun"];
            [[standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
              NSData *data = handle.availableData;

              if (data.length) {
                  NSString *message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

                  if (isInteractive && data.taskData_isInteractive) {
                      DevLog(@"Prompting for interaction: %@", message);

                      // ATTN: the "return" here only returns from the FH readability block,
                      // not the `-configureFileHandles:` method
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
                          if (total){
                              fullMessage = [[NSString stringWithFormat:@"(%d/%d) %@", cntStr, totStr, message] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                          } else {
                              fullMessage = message.trimmed;
                          }
                      }

                      double progress = ((count / total) * 100);

                      LGAutoPkgTaskResponseObject *response = [[LGAutoPkgTaskResponseObject alloc] init];
                      response.progressMessage = fullMessage;
                      response.progress = progress;
                      count++;

                      [(NSObject *)_taskStatusDelegate performSelectorOnMainThread:@selector(didReceiveStatusUpdate:) withObject:response waitUntilDone:NO];

                      // If verboseAutoPkgRun is not enabled, log the limited message here.
                      if (!verbose) {
                          NSLog(@"%@", message);
                      }
                  }
                  // If verboseAutoPkgRun is enabled, log everything generated by autopkg run -v.
                  if (verbose) {
                      NSLog(@"%@", message);
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
                  _standardOutData = [[NSMutableData alloc] init];
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

- (void)configurePreProcessors {
    // If an autopkg run has been setup using a custom implementation
    // that includes explicitly declared preprocessors don't override
    // those settings.
    if([self.internalArgs containsObject:@"--pre"] ||
       [self.internalArgs containsObject:@"--preprocessor"]){
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Since the MunkiSetDefaultCatalog is part of the core autopkg lib,
    // we've included an explicit default to check for that.
    NSString *msdcKey = @"MunkiSetDefaultCatalog";
    if (![self.internalArgs containsObject:msdcKey]) {
        if ([defaults boolForKey:kLGMunkiSetDefaultCatalogEnabledKey]) {
            [self.internalArgs addObjectsFromArray:@[@"--pre", msdcKey]];
        }
    }

    NSArray *preprocessors = [defaults arrayForKey:kLGPreProcessorDefaultsKey];
    if (preprocessors.count) {
        [preprocessors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            // Prevent adding a duplicate entry.
            if (![self.internalArgs containsObject:obj]) {
                [self.internalArgs addObjectsFromArray:@[@"--pre", obj]];
            }
        }];
    }
}

- (void)configurePostProcessors {
    // If an autopkg run has been setup using a custom implementation
    // that includes explicitly declared postprocessors don't override
    // those settings.
    if([self.internalArgs containsObject:@"--post"] ||
       [self.internalArgs containsObject:@"--postprocessor"]){
        return;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *postprocessors = [defaults arrayForKey:kLGPostProcessorDefaultsKey];
    if (postprocessors.count) {
        [postprocessors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            // Prevent adding a duplicate entry.
            if (![self.internalArgs containsObject:obj]) {
                [self.internalArgs addObjectsFromArray:@[@"--post", obj]];
            }
        }];
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
    BOOL isInteractiveOperation = NO;
    if([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_5_0]){
        if (_verb == kLGAutoPkgInfo) {
            isInteractiveOperation = YES;
        } else if (_verb == kLGAutoPkgRun){
             /* AutoPkg 0.5.0 had a small bug with make_suggestions when the `load_recipe()`
              * is called for a parent recipe. Addressed by PR https://github.com/autopkg/autopkg/pull/224
              * Slated for 0.5.2 release */
            if ([_version version_isGreaterThanOrEqualTo:AUTOPKG_0_5_2]){
                if (![_arguments containsObject:@"--recipe-list"]) {
                    isInteractiveOperation = YES;
                }
            } else {
                isInteractiveOperation = YES;
            }

        }
    }
    return isInteractiveOperation;
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
    /*
     * TODO: As of 9/16/2015 AutoPkg's search feature is not designed to 
     * successfully locate parent recipes by identifier, the primary use case
     * for AutoPkgr. So we just pipe in "n" (no) to trigger the end of run.
     */
    if (self.task.isRunning) {
        DevLog(@"Declining AutoPkg GitHub search request");
        [[self.task.standardInput fileHandleForWriting] writeData:[@"n\n" dataUsingEncoding:NSUTF8StringEncoding]];
        return;
    }

    /* Eventually there may be more ways to interact, for now it's only to search github for a recipe's repo */
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSString *title = LGAutoPkgLocalizedString(@"Could not find the parent recipe", nil);

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

        if (self.task.isRunning) {
            [[self.task.standardInput fileHandleForWriting] writeData:[results dataUsingEncoding:NSUTF8StringEncoding]];
        }
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
      reply(weakTask.report, error);
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
      reply(weakTask.report, error);
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
      if (!error) {
          path = [strongTask.standardOutString.trimmed mutableCopy];
          [path deleteCharactersInRange:[path rangeOfString:@"Override file saved to "]];
          if ((path.length > 2) && ([path characterAtIndex:path.length - 1] == '.')) {
              [path deleteCharactersInRange:NSMakeRange(path.length - 1, 1)];
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
        repo = [repo stringByAppendingString:@".git"];
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
    return [results isKindOfClass:[NSArray class]] ? results : @[];
}

#pragma mark--Processor Methods--
+ (NSArray *)listProcessors
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"list-processors" ]];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : @[];
}

+ (NSString *)processorInfo:(NSString *)processor
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"processor-info", processor ]];
    [task launch];
    return task.standardOutString;
}

#pragma mark - Other
#pragma mark-- GitHub API token --
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
    [self generateGitHubAPIToken:username password:password twoFactorCode:nil reply:reply];
}

+ (void)generateGitHubAPIToken:(NSString *)username password:(NSString *)password twoFactorCode:(NSString *)twoFactorCode reply:(void (^)(NSError *))reply
{

    NSString *tokenFile = nil;
    if (![self apiTokenFileExists:&tokenFile]) {
        AFHTTPRequestOperationManager *manager = [self tokenRequestManager:username password:password twoFactorCode:twoFactorCode];

        NSDictionary *parameters = @{ @"note" : @"AutoPkg CLI" };

        [manager POST:@"/authorizations"
            parameters:parameters
            success:^(AFHTTPRequestOperation *operation, NSDictionary *responseObject) {
              NSError *error = nil;
              NSString *tokenString = responseObject[@"token"];

              if (tokenString.length) {
                  [tokenString writeToFile:tokenFile atomically:YES encoding:NSUTF8StringEncoding error:&error];
              }
              reply(error);

            }
            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
              NSDictionary *headers = operation.response.allHeaderFields;
              if (operation.response.statusCode == 401 && [headers[@"X-GitHub-OTP"] hasPrefix:@"required"]) {
                  NSString *tfa = [self promptForTwoFactorAuthCode];
                  if (tfa.length) {
                      [self generateGitHubAPIToken:username password:password twoFactorCode:tfa reply:reply];
                  } else {
                      reply([LGAutoPkgErrorHandler errorWithGitHubAPIErrorCode:kLGAutoPkgErrorGHApi2FAAuthRequired]);
                  }
              } else {
                  reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
              }
            }];
    } else {
        reply(nil);
    }
}

+ (void)deleteGitHubAPIToken:(NSString *)username password:(NSString *)password reply:(void (^)(NSError *))reply
{
    [self deleteGitHubAPIToken:username password:password twoFactorCode:nil reply:reply];
}

+ (void)deleteGitHubAPIToken:(NSString *)username password:(NSString *)password twoFactorCode:(NSString *)twoFactorCode reply:(void (^)(NSError *))reply
{
    AFHTTPRequestOperationManager *manager = [self tokenRequestManager:username password:password twoFactorCode:twoFactorCode];

    [manager GET:@"/authorizations"
        parameters:nil
        success:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
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
              [manager DELETE:delete
                  parameters:@{}
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    // remove the file
                    NSString *tokenFile = nil;
                    NSError *error = nil;
                    if ([self apiTokenFileExists:&tokenFile]) {
                        [[NSFileManager defaultManager] removeItemAtPath:tokenFile error:&error];
                    }
                    reply(error);
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
                  }];
          } else {
              reply([LGAutoPkgErrorHandler errorWithGitHubAPIErrorCode:kLGAutoPkgErrorAPITokenNotOnRemote]);
          }
        }
        failure:^(AFHTTPRequestOperation *operation, NSError *error) {

          NSDictionary *headers = operation.response.allHeaderFields;
          if (operation.response.statusCode == 401 && [headers[@"X-GitHub-OTP"] hasPrefix:@"required"]) {
              // GitHub only seems to send 2FA with POST request, not GET (as of7/25/15 )
              // Do the request again this time specifying POST.
              [manager POST:@"/authorizations"
                  parameters:nil
                  success:^(AFHTTPRequestOperation *operation, id responseObject) {
                    // We should never get here, but in case we do send a reply so the UI doesn't hang.
                    reply(nil);
                  }
                  failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                    NSString *newTwoFactorCode = [self promptForTwoFactorAuthCode];
                    if (newTwoFactorCode.length) {
                        [self deleteGitHubAPIToken:username password:password twoFactorCode:newTwoFactorCode reply:reply];
                    } else {
                        reply([LGAutoPkgErrorHandler errorWithGitHubAPIErrorCode:kLGAutoPkgErrorGHApi2FAAuthRequired]);
                    }
                  }];
          } else {
              reply(operation.response ? [LGError errorWithResponse:operation.response] : error);
          }
        }];
}

+ (AFHTTPRequestOperationManager *)tokenRequestManager:(NSString *)username password:(NSString *)password twoFactorCode:(NSString *)twoFactorCode
{
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"https://api.github.com"]];

    manager.responseSerializer = [AFJSONResponseSerializer serializer];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];

    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:username
                                                              password:password];

    NSDictionary *defaultHeaders = @{
        @"Accept" : @"application/vnd.github.v3+json",
        @"User-Agent" : @"AutoPkg",
    };

    [defaultHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
      [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
    }];

    if (twoFactorCode) {
        [manager.requestSerializer setValue:twoFactorCode forHTTPHeaderField:@"X-GitHub-OTP"];
    }

    return manager;
}

+ (NSString *)promptForTwoFactorAuthCode
{
    NSString *code;
    LGTwoFactorAuthAlert *alert = [[LGTwoFactorAuthAlert alloc] init];

    NSModalResponse button = [alert runModal];
    if (button == NSAlertFirstButtonReturn) {
        code = [alert authorizatoinCode];
    }

    return code;
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

+ (BOOL)instanceIsRunning
{
    NSArray *runningArgs = @[ autopkg(), @"run", @"--recipe-list" ];
    NSArray *matchedProcs = [BSDProcessInfo allProcessesWithName:@"Python"
                                               matchingArguments:runningArgs];

    if (matchedProcs.count) {
        DLog(@"Another autopkg run recipe process detected: %@", matchedProcs);
    }
    return (matchedProcs.count != 0);
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
