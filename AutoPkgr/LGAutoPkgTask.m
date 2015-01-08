//
//  LGAutoPkgTask.m
//  AutoPkgr
//
//  Created by Eldon on 8/30/14.
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

#import "LGAutoPkgTask.h"
#import "LGRecipes.h"
#import "LGVersionComparator.h"
#import "AHProxySettings.h"
#import "LGHostInfo.h"
#import "LGVersioner.h"

NSString *const kLGAutoPkgTaskLock = @"com.lindegroup.autopkg.task.lock";

NSString *const kLGAutoPkgRecipeNameKey = @"Name";
NSString *const kLGAutoPkgRecipeIdentifierKey = @"Identifier";
NSString *const kLGAutoPkgRecipeParentKey = @"ParentRecipe";
NSString *const kLGAutoPkgRecipePathKey = @"Path";
NSString *const kLGAutoPkgRepoNameKey = @"RepoName";
NSString *const kLGAutoPkgRepoPathKey = @"RepoPath";
NSString *const kLGAutoPkgRepoURLKey = @"RepoURL";

// This is a function so in the future this could be configured to
// determine autopkg path in a more robust way.
NSString *const autopkg()
{
    return @"/usr/local/bin/autopkg";
}

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
@property (strong, nonatomic) LGVersioner *versioner;

// Results objects
@property (copy, nonatomic) NSString *reportPlistFile;
@property (copy, nonatomic) NSDictionary *report;
@property (copy, nonatomic, readwrite) NSArray *results;
@property (strong, nonatomic) NSError *error;

// Version
@property (copy, nonatomic) NSString *version;
@property (nonatomic, assign) BOOL AUTOPKG_VERSION_0_4_0;

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
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.replyReportBlock = reply;
    [self addOperation:task];
}

- (void)runRecipeList:(NSString *)recipeList
           updateRepo:(BOOL)updateRepo
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *runTask = [LGAutoPkgTask runRecipeListTask];
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
    self = [super init];
    if (self) {
        self.internalArgs = [@[ autopkg() ] mutableCopy];
        _taskLock = [[NSRecursiveLock alloc] init];
        _taskLock.name = kLGAutoPkgTaskLock;
        _taskStatusDelegate = self;
        _isExecuting = NO;
        _isFinished = NO;
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
        NSTask *task = [[NSTask alloc] init];

        self.task = task;
        self.task.launchPath = @"/usr/bin/python";
        self.task.arguments = [self.internalArgs copy];

        // If an instance of autopkg is running,
        // and we're trying to do a run, exit
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

        // This is the one place we refer back to the allocated task
        // to avoid retain cycles
        [task setTerminationHandler:^(NSTask *task) {
            [self didCompleteTaskExecution];
        }];

        // Since NSTask can raise for unexpected reasons,
        // put it in a try-catch block
        @try {
            [self.task launch];
        }
        @catch (NSException *exception)
        {
            NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"A fatal error occured when trying to run AutoPkg",
                                        NSLocalizedRecoverySuggestionErrorKey : @"If you repeatedly see this message please report it. The full scope of the error is in the system.log, make sure to include that in the report"
            };

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

    if (!_error) {
        [self.taskLock lock];
        self.error = [LGError errorWithTaskError:self.task verb:_verb];
        [self.taskLock unlock];
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
    [mgr addOperationAndWait:self];
}

- (void)launchInBackground:(void (^)(NSError *))reply
{
    LGAutoPkgTaskManager *bgQueue = [LGAutoPkgTaskManager new];
    DLog(@"bgQueue: %@", bgQueue.name);
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
    [self.internalArgs addObjectsFromArray:arguments];

    NSString *verbString = [_arguments firstObject];
    if ([verbString isEqualToString:@"version"]) {
        _verb = kLGAutoPkgVersion;
    } else if ([verbString isEqualToString:@"run"]) {
        _verb = kLGAutoPkgRun;
        if (self.AUTOPKG_VERSION_0_4_0) {
            [self.internalArgs addObject:self.reportPlistFile];
        }
        [self.internalArgs addObject:@"-v"];
    } else if ([verbString isEqualToString:@"search"]) {
        _verb = kLGAutoPkgSearch;
    } else if ([verbString isEqualToString:@"list-recipes"]) {
        _verb = kLGAutoPkgRecipeList;
    } else if ([verbString isEqualToString:@"make-override"]) {
        _verb = kLGAutoPkgMakeOverride;
    } else if ([verbString isEqualToString:@"repo-add"]) {
        _verb = kLGAutoPkgRepoAdd;
    } else if ([verbString isEqualToString:@"repo-delete"]) {
        _verb = kLGAutoPkgRepoDelete;
    } else if ([verbString isEqualToString:@"repo-list"]) {
        _verb = kLGAutoPkgRepoList;
    } else if ([verbString isEqualToString:@"repo-update"]) {
        _verb = kLGAutoPkgRepoUpdate;
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
#pragma mark - Task config helpers
- (void)configureFileHandles
{
    NSPipe *standardOutput = [NSPipe pipe];
    self.task.standardOutput = standardOutput;

    NSPipe *standardError = [NSPipe pipe];
    self.task.standardError = standardError;

    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgRepoUpdate) {
        if (self.AUTOPKG_VERSION_0_4_0) {
            __block double count = 0.0;
            __block double total;
            NSPredicate *progressPredicate;

            if (_verb == kLGAutoPkgRun) {
                _versioner = [[LGVersioner alloc] init];
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] 'Processing'"];
                total = [self recipeListCount];
            } else if (_verb == kLGAutoPkgRepoUpdate) {
                progressPredicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS[cd] '.git'"];
                total = [[[self class] repoList] count];
            }

            BOOL verbose = [[NSUserDefaults standardUserDefaults] boolForKey:@"verboseAutoPkgRun"];
            [[standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
                NSString *message = [[NSString alloc]initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
                
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
            }];
        }
    } else {
        [[standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fh) {
            NSData *data = [fh availableData];
            if ([data length]) {
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

    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgRepoUpdate) {
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
- (NSString *)standardErrString
{
    [self.taskLock lock];
    if (!_standardErrString && !self.task.isRunning) {
        NSData *data;
        if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
            data = [[self.task.standardError fileHandleForReading] readDataToEndOfFile];
            if (data) {
                _standardErrString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
            }
        }
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

    if (self.AUTOPKG_VERSION_0_4_0) {
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
        NSString *resultString = self.standardOutString;
        if (resultString) {

            if (_verb == kLGAutoPkgSearch) {
                __block NSMutableArray *searchResults;

                NSMutableCharacterSet *skippedCharacters = [NSMutableCharacterSet whitespaceCharacterSet];

                NSMutableCharacterSet *repoCharacters = [NSMutableCharacterSet alphanumericCharacterSet];
                [repoCharacters formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];

                NSPredicate *nonRecipePredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'To add' \
                                                   or SELF BEGINSWITH '----' \
                                                   or SELF BEGINSWITH 'Name'"];

                [resultString enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
                    if (![nonRecipePredicate evaluateWithObject:line ]) {
                        NSScanner *scanner = [NSScanner scannerWithString:line];
                        [scanner setCharactersToBeSkipped:skippedCharacters];

                        NSString *recipe, *repo, *path;

                        [scanner scanCharactersFromSet:repoCharacters intoString:&recipe];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&repo];
                        [scanner scanCharactersFromSet:repoCharacters intoString:&path];

                        if (recipe && repo && path) {
                            if (!searchResults) {
                                searchResults = [[NSMutableArray alloc] init];
                            }
                            [searchResults addObject:@{kLGAutoPkgRecipeNameKey:[recipe stringByDeletingPathExtension],
                                                       kLGAutoPkgRepoNameKey:repo,
                                                       kLGAutoPkgRecipePathKey:path,
                                                       }];
                        }
                    }
                }];
                _results = [searchResults copy];

            } else if (_verb == kLGAutoPkgRepoList) {
                NSArray *listResults = [resultString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

                NSMutableArray *strippedRepos = [[NSMutableArray alloc] init];

                for (NSString *repo in [listResults removeEmptyStrings]) {
                    NSArray *splitArray = [repo componentsSeparatedByString:@"("];
                    
                    NSString *repoURL = [[splitArray lastObject] stringByReplacingOccurrencesOfString:@")" withString:@""];
                    NSString *repoPath = [[splitArray firstObject] stringByStandardizingPath];

                    NSDictionary *resultDict = @{
                        kLGAutoPkgRepoURLKey : [repoURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],
                        kLGAutoPkgRepoPathKey : [repoPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]],
                    };
                    [strippedRepos addObject:resultDict];
                }
                _results = strippedRepos.count ? [strippedRepos copy] : nil;

            } else if (_verb == kLGAutoPkgRecipeList) {
                // Try to serialize the stdout, if that fails continue
                if ((_results = [self serializePropertyListString:resultString])) {
                    return _results;
                }

                NSArray *listResults = [resultString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                NSMutableArray *strippedRecipes = [NSMutableArray arrayWithCapacity:listResults.count];

                for (NSString *rawString in [listResults removeEmptyStrings]) {
                    NSArray *splitArray = [rawString componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

                    NSMutableDictionary *resultsDict = [NSMutableDictionary new];
                    if (splitArray.count > 1) {
                        [resultsDict setObject:splitArray[1] forKey:kLGAutoPkgRecipeIdentifierKey];
                    }

                    if (splitArray.count) {
                        [resultsDict setObject:splitArray[0] forKey:kLGAutoPkgRecipeNameKey];
                        [strippedRecipes addObject:resultsDict];
                    }
                }
                _results = strippedRecipes.count ? [strippedRecipes copy] : nil;
            }
        }
    }
    return _results;
}

#pragma mark - Utility

- (BOOL)AUTOPKG_VERSION_0_4_0
{
    return [LGVersionComparator isVersion:self.version greaterThanVersion:@"0.3.9"];
}

- (BOOL)isNetworkOperation
{
    if (_verb == kLGAutoPkgRun || _verb == kLGAutoPkgSearch || _verb == kLGAutoPkgRepoAdd || _verb == kLGAutoPkgRepoUpdate) {
        return YES;
    }
    return NO;
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
    if (string && ![string isEqualToString:@""]) {
        NSData *plistData = [string dataUsingEncoding:NSUTF8StringEncoding];
        // Initialize our dict
        results = [NSPropertyListSerialization propertyListWithData:plistData
                                                            options:NSPropertyListImmutable
                                                             format:nil
                                                              error:nil];
    }
    return results;
}

#pragma mark - Class Methods

#pragma mark-- Recipe Methods --
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *, double))progress
             reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.progressUpdateBlock = progress;

    __weak LGAutoPkgTask *weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask runRecipeListTask];
    task.progressUpdateBlock = progress;

    __weak LGAutoPkgTask *weakTask = task;
    [task launchInBackground:^(NSError *error) {
        reply(weakTask.report,error);
    }];
}

+ (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [LGAutoPkgTask searchTask:recipe];
    __weak LGAutoPkgTask *weakTask = task;
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
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"make-override", recipe ];
    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        typeof(task) strongTask = weakTask;
        NSString *path = [[strongTask.standardOutString stringByReplacingOccurrencesOfString:@"Override file saved to " withString:@""] stringByDeletingPathExtension];
        reply(path,error);
    }];
}

+ (void)makeOverride:(NSString *)recipe name:(NSString *)name reply:(void (^)(NSString *, NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"make-override", recipe, @"-n", name ];
    __weak typeof(task) weakTask = task;
    [task launchInBackground:^(NSError *error) {
        typeof(task) strongTask = weakTask;
        NSString *path = [[strongTask.standardOutString stringByReplacingOccurrencesOfString:@"Override file saved to " withString:@""] stringByDeletingPathExtension];
        reply(path,error);
    }];
}

+ (NSArray *)listRecipes
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"list-recipes" ]];
    [task launch];
    id results = [task results];
    return [results isKindOfClass:[NSArray class]] ? results : nil;
}

#pragma mark-- Repo Methods
+ (void)repoAdd:(NSString *)repo reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-add", repo ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoRemove:(NSString *)repo reply:(void (^)(NSError *))reply
{
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

+ (NSString *)version
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"version" ]];
    [task launch];
    return [task standardOutString];
}

#pragma mark-- Convenience Initializers --
+ (LGAutoPkgTask *)runRecipeTask:(NSArray *)recipes
{
    LGAutoPkgTask *task = nil;
    if (recipes.count) {
        NSMutableArray *fullRecipes = [[NSMutableArray alloc] initWithCapacity:recipes.count + 2];

        [fullRecipes addObject:@"run"];
        [fullRecipes addObjectsFromArray:recipes];
        [fullRecipes addObject:@"--report-plist"];

        task = [[LGAutoPkgTask alloc] initWithArguments:[NSArray arrayWithArray:fullRecipes]];
    }

    return task;
}

+ (LGAutoPkgTask *)runRecipeListTask
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"run", @"--recipe-list", [LGRecipes recipeList], @"--report-plist" ];
    return task;
}

+ (LGAutoPkgTask *)searchTask:(NSString *)recipe
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"search", recipe ]];
    return task;
}

+ (LGAutoPkgTask *)repoUpdateTask
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-update", @"all" ]];
    return task;
}

+ (LGAutoPkgTask *)addRepoTask:(NSString *)repo
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] initWithArguments:@[ @"repo-add", repo ]];
    return task;
}

#pragma mark-- Other Methods --
+ (BOOL)instanceIsRunning
{
    NSTask *task = [NSTask new];

    task.launchPath = @"/bin/ps";
    task.arguments = @[ @"-e", @"-o", @"command=" ];
    task.standardOutput = [NSPipe pipe];
    task.standardError = task.standardOutput;

    [task launch];
    [task waitUntilExit];

    NSData *outputData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
    NSString *outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF CONTAINS %@", autopkg()];
    NSArray *runningProcs = [outputString componentsSeparatedByString:@"\n"];

    if ([[runningProcs filteredArrayUsingPredicate:predicate] count]) {
        return YES;
    }
    return NO;
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
