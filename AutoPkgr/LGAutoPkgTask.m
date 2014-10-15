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

NSString *const kLGAutoPkgTaskLock = @"com.lindegroup.autopkg.task.lock";

NSString *const kLGAutoPkgRecipeKey = @"recipe";
NSString *const kLGAutoPkgRecipePathKey = @"recipe_path";
NSString *const kLGAutoPkgRepoKey = @"repo";
NSString *const kLGAutoPkgRepoPathKey = @"repo_path";

// This is a function so in the future this could be configured to
// determine autopkg path in a more robust way.
NSString *autopkg()
{
    return @"/usr/local/bin/autopkg";
}

@interface LGAutoPkgTask ()

@property (strong, atomic) NSTask *task;
@property (strong, atomic) NSMutableArray *internalArgs;
@property (strong, atomic) NSMutableDictionary *internalEnvironment;
@property (nonatomic, assign) LGAutoPkgVerb verb;
@property (strong, nonatomic, readwrite) NSString *standardOutString;
@property (strong, nonatomic, readwrite) NSString *standardErrString;
@property (copy, nonatomic) NSString *reportPlistFile;
@property (copy, nonatomic) NSDictionary *reportPlist;
@property (copy, nonatomic) NSString *version;
@property (nonatomic, assign) BOOL AUTOPKG_VERSION_0_4_0;
@property (nonatomic, readwrite, assign) BOOL complete;
@property (strong, nonatomic) NSOperationQueue *taskQueue;
@property (strong, nonatomic) NSOperationQueue *statusUpdateQueue;
@property (readwrite, nonatomic, strong) NSRecursiveLock *taskLock;

@end

@implementation LGAutoPkgTask

- (NSString *)taskDescription
{
    return [NSString stringWithFormat:@"%@ %@", self.task.launchPath, [self.task.arguments componentsJoinedByString:@" "]];
}

- (void)dealloc
{
    DLog(@"Completed AutoPkg Task:\n  %@\n", [self taskDescription]);
    self.task.terminationHandler = nil;
    self.runStatusUpdate = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.complete = NO;
        self.internalArgs = [[NSMutableArray alloc] initWithArray:@[ autopkg() ]];
        self.statusUpdateQueue = [NSOperationQueue currentQueue];
        self.taskLock = [[NSRecursiveLock alloc] init];
        self.taskLock.name = kLGAutoPkgTaskLock;
    }
    return self;
}

#pragma mark - Life Cycle
- (BOOL)launch:(NSError *__autoreleasing *)error
{
    self.task = [[NSTask alloc] init];
    self.task.launchPath = @"/usr/bin/python";

    [self.task setArguments:self.internalArgs];

    // If an instance of autopkg is running,
    // and we're trying to do a run, exit
    if (_verb == kLGAutoPkgRun && [[self class] instanceIsRunning]) {
        return [LGError errorWithCode:kLGErrorMultipleRunsOfAutopkg
                                error:error];
    }

    [self configureFileHandles];
    [self configureEnvironment];

    if (self.internalEnvironment) {
        self.task.environment = self.internalEnvironment;
    }

    [self.task launch];

    while ([self.task isRunning]) {
        [[NSRunLoop currentRunLoop] runMode:@"kLGAutoPkgTaskRunLoopMode"
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }

    [self setComplete:YES];
    // make sure the out and error readability handlers get set to nil
    // so the filehandle will get closed
    if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
        [self.task.standardOutput fileHandleForReading].readabilityHandler = nil;
    }

    if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
        [self.task.standardError fileHandleForReading].readabilityHandler = nil;
    }

    [self.taskLock lock];
    BOOL success = [LGError errorWithTaskError:self.task verb:_verb error:error];
    [self.taskLock unlock];

    return success;
}

- (void)launchInBackground:(void (^)(NSError *))reply
{
    self.taskQueue = [NSOperationQueue new];
    [self.taskQueue addOperationWithBlock:^{
        NSError *error;
        [self launch:&error];
        reply(error);
    }];
}

- (BOOL)cancel
{
    BOOL canceled = YES;
    [self.taskLock lock];
    if (self.task && self.task.isRunning) {
        [self.task terminate];
        canceled = ![self.task isRunning];
    }
    [self.taskLock unlock];
    return canceled;
}

- (BOOL)complete
{
    if (!_complete) {
        [self.taskLock lock];
        if (self.task)
            _complete = ![self.task isRunning];
        [self.taskLock unlock];
    }
    return _complete;
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
    if ([verbString isEqualToString:@"run"]) {
        _verb = kLGAutoPkgRun;
        if (self.AUTOPKG_VERSION_0_4_0) {
            [self.internalArgs addObject:self.reportPlistFile];
        }
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
    } else if ([verbString isEqualToString:@"version"]) {
        _verb = kLGAutoPkgVersion;
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
    self.task.standardError = [NSPipe pipe];
    self.task.standardOutput = [NSPipe pipe];

    if (_verb == kLGAutoPkgRun) {
        if (self.AUTOPKG_VERSION_0_4_0) {
            __block double count = 0.0;
            __block double total = [self recipeListCount];
            __weak LGAutoPkgTask *weakSelf = self;

            NSPredicate *processingPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'Processing'"];
            [[self.task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
                int cntStr = (int)round(count) + 1;
                int totStr = (int)round(total);
                NSString *message = [[NSString alloc]initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
                NSString *fullMessage;
                if ([processingPredicate evaluateWithObject:message]) {
                    fullMessage = [[NSString stringWithFormat:@"(%d/%d) %@", cntStr, totStr, message] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];

                    if (weakSelf.runStatusUpdate) {
                        [weakSelf.statusUpdateQueue addOperationWithBlock:^{
                            weakSelf.runStatusUpdate(fullMessage, ((count/total) * 100));
                        }];
                    }
                    if (count < total) {
                        count++;
                    }
                }
            }];
        }
    }
}

- (void)configureEnvironment
{
    // If the task is a network operation set proxies
    if ([self isNetworkOperation]) {

        LGDefaults *defaults = [[LGDefaults alloc] init];
        NSString *httpProxy = [defaults objectForKey:@"HTTP_PROXY"];
        NSString *httpsProxy = [defaults objectForKey:@"HTTPS_PROXY"];

        if (httpProxy) {
            [self addEnvironmentVariable:httpProxy forKey:@"HTTP_PROXY"];
            DLog(@"Using HTTP_PROXY: %@", httpProxy);
        }

        if (httpsProxy) {
            [self addEnvironmentVariable:httpsProxy forKey:@"HTTPS_PROXY"];
            DLog(@"Using HTTPS_PROXY: %@", httpsProxy);
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
        _internalEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    }
    [_internalEnvironment setObject:variable forKey:key];
}

#pragma mark - Output / Results
- (NSString *)standardErrString
{
    [self.taskLock lock];
    if (!_standardErrString && self.complete) {
        NSData *data;
        if ([self.task.standardError isKindOfClass:[NSPipe class]]) {
            data = [[self.task.standardError fileHandleForReading] readDataToEndOfFile];
        }
        if (data) {
            _standardErrString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        }
    }
    [self.taskLock unlock];
    return _standardErrString;
}

- (NSString *)standardOutString
{
    [self.taskLock lock];
    if (!_standardOutString && self.complete) {
        NSData *data;
        if ([self.task.standardOutput isKindOfClass:[NSPipe class]]) {
            data = [[self.task.standardOutput fileHandleForReading] readDataToEndOfFile];
        }
        if (data) {
            _standardOutString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        }
    }
    [self.taskLock unlock];
    return _standardOutString;
}

- (NSDictionary *)reportPlist
{
    if (self.AUTOPKG_VERSION_0_4_0) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *reportPlistFile = self.reportPlistFile;

        if (self.reportPlistFile && [fm fileExistsAtPath:self.reportPlistFile]) {
            // Create dictionary from the tmp file
            _reportPlist = [NSDictionary dictionaryWithContentsOfFile:reportPlistFile];

            // Cleanup the tmp file
            NSError *error;
            if (![fm removeItemAtPath:reportPlistFile error:&error]) {
                DLog(@"Error removing autopkg run report-plist: %@", error.localizedDescription);
            }
        }
    } else {
        NSString *plistString = self.standardOutString;
        if (plistString && ![plistString isEqualToString:@""]) {
            // Convert string back to data for plist serialization
            NSData *plistData = [plistString dataUsingEncoding:NSUTF8StringEncoding];
            // Initialize plist format
            NSPropertyListFormat format;
            // Initialize our dict
            _reportPlist = [NSPropertyListSerialization propertyListWithData:plistData
                                                                     options:NSPropertyListImmutable
                                                                      format:&format
                                                                       error:nil];
        }
    }
    return _reportPlist;
}

- (NSString *)reportPlistFile
{
    if (!_reportPlistFile) {
        _reportPlistFile = [NSTemporaryDirectory() stringByAppendingString:[[NSProcessInfo processInfo] globallyUniqueString]];
    }
    return _reportPlistFile;
}

- (NSArray *)results
{
    NSString *resultString = self.standardOutString;
    NSArray *results = nil;

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
                        [searchResults addObject:@{kLGAutoPkgRecipeKey:[recipe stringByDeletingPathExtension],
                                             kLGAutoPkgRepoKey:repo,
                                             kLGAutoPkgRepoPathKey:path,
                                             }];
                    }
                }
            }];
            results = [NSArray arrayWithArray:searchResults];
        } else if (_verb == kLGAutoPkgRepoList || _verb == kLGAutoPkgRecipeList) {
            NSArray *listResults = [resultString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            NSPredicate *noEmptyStrings = [NSPredicate predicateWithFormat:@"not (SELF == '')"];
            results = [listResults filteredArrayUsingPredicate:noEmptyStrings];
        }
    }
    return results;
}

#pragma mark - Utility

- (BOOL)AUTOPKG_VERSION_0_4_0
{
    return [LGVersionComparator isVersion:self.version greaterThanVersion:@"0.3.9"];
}

- (BOOL)isNetworkOperation
{
    if (_verb == kLGAutoPkgRun ||
        _verb == kLGAutoPkgSearch ||
        _verb == kLGAutoPkgRepoAdd ||
        _verb == kLGAutoPkgRepoUpdate) {
        return YES;
    }
    return NO;
}

#pragma mark - Specialized settings
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

#pragma mark - Convenience Instance Methods
- (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *))progress
             reply:(void (^)(NSError *))reply
{
    NSMutableArray *fullRecipes = [[NSMutableArray alloc] init];
    [fullRecipes addObject:@"run"];
    for (NSString *recipe in recipes) {
        [fullRecipes addObject:recipe];
    }

    [fullRecipes addObjectsFromArray:@[ @"-v", @"--report-plist" ]];
    self.arguments = [NSArray arrayWithArray:fullRecipes];

    [self setRunStatusUpdate:^(NSString *message, double progressUpdate) {
        progress(message);
    }];

    [self launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

- (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    self.arguments = @[ @"run", @"--recipe-list", recipeList, @"--report-plist" ];

    [self setRunStatusUpdate:^(NSString *message, double progressUpdate) {
        progress(message, progressUpdate);
    }];

    [self launchInBackground:^(NSError *error) {
        reply(self.reportPlist, error);
    }];
}

#pragma mark - Class Methods
#pragma mark-- Recipe Methods
+ (void)runRecipes:(NSArray *)recipes
          progress:(void (^)(NSString *))progress
             reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    [task runRecipes:recipes progress:^(NSString *message) {
        progress(message);
    } reply:^(NSError *error) {
        reply(error);
    }];
}

+ (void)runRecipeList:(NSString *)recipeList
             progress:(void (^)(NSString *, double))progress
                reply:(void (^)(NSDictionary *, NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    [task runRecipeList:recipeList progress:^(NSString *message, double prog) {
        progress(message, prog);
    } reply:^(NSDictionary *report, NSError *error) {
        reply(report, error);
    }];
}

+ (void)search:(NSString *)recipe reply:(void (^)(NSArray *results, NSError *error))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"search", recipe ];
    [task launchInBackground:^(NSError *error) {
        NSArray *results;
        if (!error) {
            results = [task results];
        }
        reply(results, error);
    }];
}

+ (void)makeOverride:(NSString *)recipe reply:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"make-override", recipe ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)listRecipes:(void (^)(NSArray *, NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"list-recipes" ];
    [task launchInBackground:^(NSError *error) {
        NSArray *results;
        if (!error) {
            results = [task results];
        }
        reply(results, error);
    }];
}

+ (NSArray *)listRecipes
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"list-recipes" ];
    [task launch:nil];
    return task.results;
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

+ (void)repoUpdate:(void (^)(NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-update", @"all" ];
    [task launchInBackground:^(NSError *error) {
        reply(error);
    }];
}

+ (void)repoList:(void (^)(NSArray *, NSError *))reply
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-list" ];
    [task launchInBackground:^(NSError *error) {
        NSArray *results;
        if (!error) {
            results = [task results];
        }
        reply(results, error);
    }];
}

+ (NSArray *)repoList
{
    LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
    task.arguments = @[ @"repo-list" ];
    if ([task launch:nil]) {
        id results = [task results];
        if ([results isKindOfClass:[NSArray class]]) {
            return results;
        }
    }
    return nil;
}

#pragma mark-- Other Methods
+ (NSString *)version
{
    LGAutoPkgTask *autoPkgTask = [[LGAutoPkgTask alloc] init];
    autoPkgTask.arguments = @[ @"version" ];
    [autoPkgTask launch:nil];
    return [autoPkgTask standardOutString];
}

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

@end
