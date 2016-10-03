//
//  LGAutoPkgRepo.m
//  AutoPkgr
//
//  Copyright 2015-2016 The Linde Group, Inc.
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

#import "LGAutoPkgRepo.h"
#import "LGAutoPkgTask.h"
#import "LGGitIntegration.h"

#import "NSData+taskData.h"

#import <AFNetworking/AFNetworking.h>

static NSArray *_activeRepos;
static NSArray *_popularRepos;

// Dispatch queue for enabling / disabling recipe
@implementation LGAutoPkgRepo {
    NSDate *_checkStatusTimeStamp;
}

@synthesize commitsURL = _commitsURL;
@synthesize homeURL = _homeURL;
@synthesize defaultBranch = _defaultBranch;

#pragma mark - Initializers

/* initWithGithHubDictionary is used to create objects
 * from repos pulled from the GitHub API */
- (instancetype)initWithGitHubDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        _name = dictionary[@"name"];
        _cloneURL = [NSURL URLWithString:dictionary[@"clone_url"]];
        _defaultBranch = dictionary[@"default_branch"] ?: @"master";

        _homeURL = [NSURL URLWithString:dictionary[@"html_url"]];
        _stars = [dictionary[@"stargazers_count"] integerValue];
    }
    return self;
}

/* initWithAutoPkgDictionary is used when a repo from the active repos
 * is not included in the list of popular repos. */
- (instancetype)initWithAutoPkgDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        _name = [[dictionary[kLGAutoPkgRepoPathKey] lastPathComponent] stringByDeletingPathExtension];
        _cloneURL = [NSURL URLWithString:dictionary[kLGAutoPkgRepoURLKey]];
    }
    return self;
}

/* initWithCloneURL is used for the fall back array */
- (instancetype)initWithCloneURL:(NSString *)cloneURL
{
    if (self = [super init]) {
        _name = [[cloneURL lastPathComponent] stringByDeletingPathExtension];
        _cloneURL = [NSURL URLWithString:cloneURL];
    }
    return self;
}

#pragma mark - Accessors
- (NSString *)description
{
    return self.cloneURL.absoluteString;
}

- (NSArray *)activeRepos
{
    if (!_activeRepos) {
        _activeRepos = [LGAutoPkgTask repoList];
    }
    return _activeRepos;
}

- (BOOL)isInstalled
{
    NSMutableString *repoURL = self.cloneURL.absoluteString.mutableCopy;
    if ([repoURL.pathExtension isEqualToString:@"git"]) {
        [repoURL deleteCharactersInRange:NSMakeRange(repoURL.length - 4, 4)];
    }

    NSPredicate *repoPredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", kLGAutoPkgRepoURLKey, repoURL];

    return [[[self activeRepos] filteredArrayUsingPredicate:repoPredicate] count];
}

- (NSString *)path
{
    for (NSDictionary *dict in [self activeRepos]) {
        if ([dict[kLGAutoPkgRepoURLKey] isEqualToString:self.cloneURL.absoluteString]) {
            return dict[kLGAutoPkgRepoPathKey];
        }
    }
    return nil;
}

- (NSString *)defaultBranch
{
    if (!_defaultBranch) {
        _defaultBranch = @"master";
    }
    return _defaultBranch;
}

- (NSURL *)homeURL
{
    if (!_homeURL) {
        if ([_cloneURL.host isEqualToString:@"github.com"]) {
            _homeURL = [NSURL URLWithString:_cloneURL.absoluteString.stringByDeletingPathExtension];
        }
    }
    return _homeURL;
}

- (NSURL *)commitsURL
{
    if (!_commitsURL) {
        if (self.homeURL) {
            _commitsURL = [_homeURL URLByAppendingPathComponent:@"commits"];
        }
    }
    return _commitsURL;
}

#pragma mark - Implementation Methods
- (void)update:(void (^)(NSError *))reply
{
    NSString *path;
    if ((path = self.path)) {
        LGAutoPkgTask *task = [[LGAutoPkgTask alloc] init];
        task.arguments = @[ @"repo-update", path ];
        [task launchInBackground:^(NSError *error) {
            if (!error) {
                [self statusDidChange:kLGAutoPkgRepoUpToDate];
            }
            reply(error);
        }];
    }
    else {
        reply([self errorWithMessage:@"Repo is not installed." code:kLGAutoPkgRepoNotInstalled]);
    }
};

- (void)install:(void (^)(NSError *))reply
{
    _activeRepos = [LGAutoPkgTask repoList];
    if (!self.isInstalled) {
        [LGAutoPkgTask repoAdd:_cloneURL.absoluteString
                         reply:^(NSError *error) {
                             _activeRepos = [LGAutoPkgTask repoList];
                             if (!error) {
                                 [self statusDidChange:kLGAutoPkgRepoUpToDate];
                             }
                             reply(error);
                         }];
    }
    else {
        reply(nil);
    }
}

- (void)remove:(void (^)(NSError *))reply
{
    [LGAutoPkgTask repoRemove:_cloneURL.absoluteString
                        reply:^(NSError *error) {
                            _activeRepos = [LGAutoPkgTask repoList];
                            if (!error) {
                                [self statusDidChange:kLGAutoPkgRepoNotInstalled];
                            }
                            reply(error);
                        }];
}

- (void)getRepoStatus:(void (^)(LGAutoPkgRepoStatus status))reply
{
    if (_checkStatusTimeStamp && [_checkStatusTimeStamp timeIntervalSinceNow] <= 0) {
        return reply(_status);
    }
    // So we don't constantly hit the network at the exact same time, space out the git calls.
    NSTimeInterval interval = arc4random_uniform(600) + 300;
    _checkStatusTimeStamp = [NSDate dateWithTimeIntervalSinceNow:interval];
    NSString *path = self.path;
    NSString *defaultBranch = self.defaultBranch;

    _status = kLGAutoPkgRepoNotInstalled;
    if (!path || !defaultBranch) {
        return reply(_status);
    }

    NSArray *locTaskArgs = @[ @"rev-parse", defaultBranch ];
    NSArray *remTaskArgs = @[ @"ls-remote", @"--heads", @"origin", @"./.", defaultBranch ];

    [LGGitIntegration gitTaskWithArguments:locTaskArgs
                                  repoPath:path
                                     reply:^(NSString *locStdOut, NSError *error) {
                                         if (error) {
                                             NSLog(@"Git Error: %@", error);
                                             _status = kLGAutoPkgRepoNotInstalled;
                                             return reply(_status);
                                         }

                                         NSString *localSHA1 = locStdOut.trimmed;
                                         [LGGitIntegration gitTaskWithArguments:remTaskArgs
                                                                       repoPath:path
                                                                          reply:^(NSString *remStdOut, NSError *error) {
                                                                              if (error) {
                                                                                  NSLog(@"Git Error: %@", error);
                                                                              }

                                                                              NSString *remoteSHA1 = remStdOut.split_bySpace.firstObject;
                                                                              if (!remoteSHA1) {
                                                                                  _status = kLGAutoPkgRepoUpToDate;
                                                                                  _checkStatusTimeStamp = [NSDate dateWithTimeIntervalSinceNow:10];
                                                                              }
                                                                              else if ([localSHA1 isEqualToString:remoteSHA1]) {
                                                                                  _status = kLGAutoPkgRepoUpToDate;
                                                                              }
                                                                              else {
                                                                                  _status = kLGAutoPkgRepoUpdateAvailable;
                                                                              }
                                                                              reply(_status);
                                                                          }];
                                     }];
}

- (void)checkRepoStatus:(id)sender
{
    [self getRepoStatus:^(LGAutoPkgRepoStatus status) {
        [self statusDidChange:status];
    }];
}

- (void)hardResetToOriginMaster
{
    if (self.path) {
        [LGGitIntegration gitTaskWithArguments:@[ @"reset", @"--hard", @"origin/master" ]
                                      repoPath:self.path
                                         reply:^(NSString *s, NSError *e) {
                                             if (!e) {
                                                 [self statusDidChange:kLGAutoPkgRepoUpToDate];
                                             }
                                         }];
    }
}

- (void)viewCommitsOnGitHub:(id)sender
{
    if (self.commitsURL) {
        [[NSWorkspace sharedWorkspace] openURL:_commitsURL];
    }
}

- (void)statusDidChange:(LGAutoPkgRepoStatus)newStatus
{
    _status = newStatus;
    if (_statusChangeBlock) {
        _statusChangeBlock(_status);
    }
}

#pragma mark - Private
- (NSError *)errorWithMessage:(NSString *)message code:(NSInteger)code
{
    return [NSError errorWithDomain:kLGApplicationName
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey : [@"There was a error with " stringByAppendingString:self.name],
                                       NSLocalizedRecoverySuggestionErrorKey : message }];
}

#pragma mark - Class Methods
+ (void)commonRepos:(void (^)(NSArray *))reply
{
    void (^constructCommonRepos)() = ^() {
        _activeRepos = [LGAutoPkgTask repoList];
        NSMutableArray *commonRepos = [NSMutableArray arrayWithArray:_popularRepos];

        [_activeRepos enumerateObjectsUsingBlock:^(NSDictionary *activeRepo, NSUInteger idx, BOOL *stop) {
            NSString *repoURL = activeRepo[kLGAutoPkgRepoURLKey];
            NSMutableString *normalizedRepo = repoURL.mutableCopy;

            if (![normalizedRepo.pathExtension isEqualToString:@"git"]) {
                /* Using -stringByAppendingPathComponent: on a URL here
                 * results in the scheme getting mangled from https://xxx to https:/xxx
                 * so just use -stringByAppendingString: string. */
                [normalizedRepo appendString:@".git"];
            }

            NSPredicate *pred = [NSPredicate predicateWithFormat:@"%K.absoluteString == %@",
                                                                 NSStringFromSelector(@selector(cloneURL)),
                                                                 normalizedRepo];

            NSArray *matches = [_popularRepos filteredArrayUsingPredicate:pred];

            if (matches.count == 0) {
                LGAutoPkgRepo *repo = nil;
                if ((repo = [[self alloc] initWithAutoPkgDictionary:activeRepo])) {
                    [commonRepos addObject:repo];
                }
            }
            if (matches.count == 1 && ![repoURL isEqualToString:normalizedRepo]) {
                LGAutoPkgRepo *repo = matches.firstObject;
                repo->_cloneURL = [NSURL URLWithString:repoURL];
            }
        }];

        for (LGAutoPkgRepo *repo in commonRepos) {
            repo->_checkStatusTimeStamp = nil;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            reply([commonRepos copy]);
        });
    };

    if (_popularRepos) {
        constructCommonRepos();
    }
    else {
        NSURL *url = [NSURL URLWithString:kLGAutoPkgRepositoriesJSONURL];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];

        NSString *apiToken = nil;
        if ((apiToken = [LGAutoPkgTask apiToken])) {
            [request setValue:[@"token " stringByAppendingString:apiToken] forHTTPHeaderField:@"Authorization"];
        }

        AFHTTPRequestOperation *op = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        op.responseSerializer = [AFJSONResponseSerializer serializer];

        [op setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, NSArray *responseObject) {
            NSMutableArray *popularRepos = [[NSMutableArray alloc] initWithCapacity:responseObject.count];
            [responseObject enumerateObjectsUsingBlock:^(NSDictionary *repoDict, NSUInteger idx, BOOL *stop) {
                if (![repoDict[@"full_name"] isEqualToString:@"autopkg/autopkg"]) {
                    LGAutoPkgRepo *repo = nil;
                    if ((repo = [[LGAutoPkgRepo alloc] initWithGitHubDictionary:repoDict])) {
                        [popularRepos addObject:repo];
                    };
                }
            }];
            _popularRepos = [popularRepos copy];
            constructCommonRepos();
        }
            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSArray *fallbackRepos = @[
                    @"https://github.com/autopkg/arubdesu-recipes.git",
                    @"https://github.com/autopkg/bochoven-recipes.git",
                    @"https://github.com/autopkg/bradclare-recipes.git",
                    @"https://github.com/autopkg/cgerke-recipes.git",
                    @"https://github.com/autopkg/clburlison-recipes.git",
                    @"https://github.com/autopkg/dankeller-recipes.git",
                    @"https://github.com/autopkg/derak-recipes.git",
                    @"https://github.com/autopkg/filewave.git",
                    @"https://github.com/autopkg/foigus-recipes.git",
                    @"https://github.com/autopkg/gerardkok-recipes.git",
                    @"https://github.com/autopkg/grahamgilbert-recipes.git",
                    @"https://github.com/autopkg/gregneagle-recipes.git",
                    @"https://github.com/autopkg/hansen-m-recipes.git",
                    @"https://github.com/autopkg/hjuutilainen-recipes.git",
                    @"https://github.com/autopkg/homebysix-recipes.git",
                    @"https://github.com/autopkg/jaharmi-recipes.git",
                    @"https://github.com/autopkg/jazzace-recipes.git",
                    @"https://github.com/autopkg/jessepeterson-recipes.git",
                    @"https://github.com/autopkg/jleggat-recipes.git",
                    @"https://github.com/autopkg/joshua-d-miller-recipes.git",
                    @"https://github.com/autopkg/jps3-recipes.git",
                    @"https://github.com/autopkg/jss-recipes.git",
                    @"https://github.com/autopkg/justinrummel-recipes.git",
                    @"https://github.com/autopkg/keeleysam-recipes.git",
                    @"https://github.com/autopkg/kitzy-recipes.git",
                    @"https://github.com/autopkg/lashomb-recipes.git",
                    @"https://github.com/autopkg/luisgiraldo-recipes.git",
                    @"https://github.com/autopkg/mosen-recipes.git",
                    @"https://github.com/autopkg/munkireport-recipes.git",
                    @"https://github.com/autopkg/n8felton-recipes.git",
                    @"https://github.com/autopkg/nmcspadden-recipes.git",
                    @"https://github.com/autopkg/novaksam-recipes.git",
                    @"https://github.com/autopkg/patgmac-recipes.git",
                    @"https://github.com/autopkg/recipes.git",
                    @"https://github.com/autopkg/robperc-recipes.git",
                    @"https://github.com/autopkg/rtrouton-recipes.git",
                    @"https://github.com/autopkg/rustymyers-recipes.git",
                    @"https://github.com/autopkg/scriptingosx-recipes.git",
                    @"https://github.com/autopkg/seansgm-recipes.git",
                    @"https://github.com/autopkg/sheagcraig-recipes.git",
                    @"https://github.com/autopkg/swy-recipes.git",
                    @"https://github.com/autopkg/timsutton-recipes.git",
                    @"https://github.com/autopkg/valdore86-recipes.git",
                    @"https://github.com/autopkg/watchmanmonitoring-recipes.git",
                ];

                NSMutableArray *popularRepos = [[NSMutableArray alloc] initWithCapacity:fallbackRepos.count];
                [fallbackRepos enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                    LGAutoPkgRepo *repo = nil;
                    if ((repo = [[LGAutoPkgRepo alloc] initWithCloneURL:obj])) {
                        [popularRepos addObject:repo];
                    }
                }];
                _popularRepos = [popularRepos copy];
                constructCommonRepos();
            }];
        [op start];
    }
}

+ (BOOL)stringIsValidRepoURL:(NSString *)urlString
{

    if (access(urlString.UTF8String, W_OK) == 0) {
        // Local folder; check if it's a git repo.
        NSString *gitCheck = [urlString stringByAppendingPathComponent:@".git"];
        return (access(gitCheck.UTF8String, W_OK) == 0);
    };

    NSString *host = nil;
    NSString *path = nil;

    // Get the first occurence of the characters using .location. Otherwise it returns NSNotFound.
    NSInteger sep1_idx = [urlString rangeOfString:@":/"].location;
    NSInteger sep2_idx = [urlString rangeOfString:@":"].location;
    NSInteger sep3_idx = [urlString rangeOfString:@"."].location;

    // Check if it conforms to scp-like syntax such as git@github.com:autopkg/recipes
    if ((sep2_idx != NSNotFound && sep1_idx == NSNotFound) || (sep1_idx > sep2_idx) || (sep2_idx > sep3_idx)) {
        // If a username is found before the ":" strip it off.
        NSInteger location = NSNotFound;
        if ((location = [urlString rangeOfString:@"@"].location) < sep2_idx) {
            urlString = [urlString substringFromIndex:location + 1];
        }
        NSURL *url = [[NSURL alloc] initWithString:urlString];
        host = [url scheme];
        NSArray *split = [urlString componentsSeparatedByString:@":"];
        if (split.count) {
            path = [[split subarrayWithRange:NSMakeRange(1, split.count - 1)] componentsJoinedByString:@":"];
        }
    }
    else {
        NSURL *url = [[NSURL alloc] initWithString:urlString];
        host = [url host];
        path = [url path];
    }

    return (host.length) && (path.length > 1);
}

@end
