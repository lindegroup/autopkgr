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
#import <util.h>

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

@property (copy, nonatomic, readwrite) NSString *standardOutString;
@property (copy, nonatomic, readwrite) NSString *standardErrString;
@property (copy, nonatomic) NSString *reportPlistFile;
@property (copy, nonatomic) NSDictionary *reportPlist;
@property (copy, nonatomic) NSString *version;
@property (nonatomic) BOOL AUTOPKG_VERSION_0_4_0;
@property (nonatomic, readwrite) BOOL complete;

@end

@implementation LGAutoPkgTask {
    NSTask *_task;
    NSMutableArray *_internalArgs;
    LGAutoPkgVerb _verb;
}

- (void)dealloc
{
    _task.terminationHandler = nil;
}

- (id)init
{
    self = [super init];
    if (self) {
        self->_task = [[NSTask alloc] init];
        self->_task.launchPath = @"/usr/bin/python";
        self->_internalArgs = [[NSMutableArray alloc] initWithArray:@[ autopkg() ]];
    }
    return self;
}

- (BOOL)launch:(NSError *__autoreleasing *)error
{
    [_task setArguments:_internalArgs];

    // If an instance of autopkg is running,
    // and we're trying to do a run, exit
    if (_verb == kLGAutoPkgRun && [[self class] instanceIsRunning]) {
        return [LGError errorWithCode:kLGErrorMultipleRunsOfAutopkg
                                error:error];
    }

    [self setFileHandles];
    [_task launch];
    [_task waitUntilExit];
    
    // set the complete property to YES in case of an observer
    _complete = YES;
    
    // make sure the out and error readability handlers get set to nil
    // so the filehandle will get closed
    if ([_task.standardOutput isKindOfClass:[NSPipe class]]) {
        [_task.standardOutput fileHandleForReading].readabilityHandler = nil;
    }
    
    if ([_task.standardError isKindOfClass:[NSPipe class]]) {
        [_task.standardError fileHandleForReading].readabilityHandler = nil;
    }

    return [LGError errorWithTaskError:_task
                                  verb:_verb
                                 error:error];
}

- (void)launchInBackground:(void (^)(NSError *))reply
{
    NSOperationQueue *bgQueue = [NSOperationQueue new];
    [bgQueue addOperationWithBlock:^{
        NSError *error;
        [self launch:&error];
        reply(error);
    }];
}

- (BOOL)cancel
{
    if (_task && _task.isRunning) {
        [_task terminate];
        return ![_task isRunning];
    }
    return YES;
}

- (void)setFileHandles
{
    _task.standardError = [NSPipe pipe];
    _task.standardOutput = [NSPipe pipe];

    if (_verb == kLGAutoPkgRun) {
        if (self.AUTOPKG_VERSION_0_4_0) {
            __block double count = 0.0;
            __block double total = [self recipeListCount];
            __weak LGAutoPkgTask *weakSelf = self;

            // To get status from autopkg set NSUnbufferedIO environment keyto YES
            // Thanks to help from -- http://stackoverflow.com/questions/8251010
            NSMutableDictionary *environment = [[NSMutableDictionary alloc] init];
            
            NSDictionary *processEnvironment = [[NSProcessInfo processInfo] environment];
            [environment addEntriesFromDictionary:processEnvironment];
            [environment addEntriesFromDictionary:@{ @"NSUnbufferedIO" : @"YES"}];
            
            _task.environment = environment;

            NSPredicate *processingPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] 'Processing'"];
            [[_task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *handle) {
                int cntStr = (int)round(count) + 1;
                int totStr = (int)round(total);
                NSString *message = [[NSString alloc]initWithData:[handle availableData] encoding:NSUTF8StringEncoding];
                NSString *fullMessage;
                if ([processingPredicate evaluateWithObject:message]) {
                    fullMessage = [NSString stringWithFormat:@"(%d/%d) %@", cntStr, totStr, message];
                } else {
                    fullMessage = message;
                }
                
                if (weakSelf.runStatusUpdate) {
                    weakSelf.runStatusUpdate(fullMessage,((count/total)*100));
                }
                
                if (count < total) {
                    count++;
                }
            }];
        }
    }
}

- (void)setArguments:(NSArray *)arguments
{
    _arguments = arguments;
    [_internalArgs addObjectsFromArray:arguments];

    NSString *verbString = _arguments[0];
    if ([verbString isEqualToString:@"run"]) {
        _verb = kLGAutoPkgRun;
        if (self.AUTOPKG_VERSION_0_4_0) {
            [_internalArgs addObject:self.reportPlistFile];
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
}

- (NSString *)standardErrString
{
    if ( !_standardErrString) {
        NSData *data;
        if ([_task.standardError isKindOfClass:[NSPipe class]]) {
            data = [[_task.standardError fileHandleForReading] readDataToEndOfFile];
        }
        if (data) {
            _standardErrString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        }
    }
    return _standardErrString;
}

- (NSString *)standardOutString
{
    if (!_standardOutString) {
        NSData *data;
        if ([_task.standardOutput isKindOfClass:[NSPipe class]]) {
            data = [[_task.standardOutput fileHandleForReading] readDataToEndOfFile];
        }
        if (data) {
            _standardOutString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        }
    }
    return _standardOutString;
}

- (NSDictionary *)reportPlist
{
    if (self.AUTOPKG_VERSION_0_4_0) {
        _reportPlist = [NSDictionary dictionaryWithContentsOfFile:_reportPlistFile];
    } else {
        NSString *plistString = self.standardOutString;
        if (![plistString isEqualToString:@""]) {
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

            NSPredicate *nonRecipePredicate = [NSPredicate predicateWithFormat:
                                                               @"SELF BEGINSWITH 'To add' \
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

- (NSString *)version
{
    if (_version) {
        return _version;
    }
    _version = [[self class] version];
    return _version;
}

- (BOOL)AUTOPKG_VERSION_0_4_0
{
    return [LGVersionComparator isVersion:self.version greaterThanVersion:@"0.3.9"];
}

#pragma mark - Specialized settings
- (NSInteger)recipeListCount
{
    NSInteger count = 0;
    if (_verb == kLGAutoPkgRun) {
        NSString *file = [_arguments objectAtIndex:2];
        if ([[NSFileManager defaultManager] fileExistsAtPath:file]) {
            NSString *fileContents = [NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:nil];
            count = [[fileContents componentsSeparatedByString:@"\n"] count];
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

+(NSArray *)repoList
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

    if ([[runningProcs filteredArrayUsingPredicate:predicate] count])
        return YES;

    return NO;
}

@end
