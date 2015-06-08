// LGAutoPkgRepos.m
//
// Copyright 2015 The Linde Group, Inc.
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
 * from repos pulled from the GitHub api */
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
- (BOOL)isInstalled
{
    NSPredicate *repoPredicate = [NSPredicate predicateWithFormat:@"%K CONTAINS[cd] %@", kLGAutoPkgRepoURLKey, self.cloneURL.absoluteString];
    return [[_activeRepos filteredArrayUsingPredicate:repoPredicate] count];
}

- (NSString *)path
{
    for (NSDictionary *dict in _activeRepos) {
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
- (void)updateRepo:(void (^)(NSError *))reply
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
    } else {
        reply([self errorWithMessage:@"Repo is not installed." code:kLGAutoPkgRepoNotInstalled]);
    }
};

- (void)install:(void (^)(NSError *))reply
{
    [LGAutoPkgTask repoAdd:_cloneURL.absoluteString reply:^(NSError *error) {
        _activeRepos = [LGAutoPkgTask repoList];
        if (!error) {
            [self statusDidChange:kLGAutoPkgRepoUpToDate];
        }
        reply(error);
    }];
}

- (void)remove:(void (^)(NSError *))reply
{
    [LGAutoPkgTask repoRemove:_cloneURL.absoluteString reply:^(NSError *error) {
        _activeRepos = [LGAutoPkgTask repoList];
        if (!error) {
            [self statusDidChange:kLGAutoPkgRepoNotInstalled];
        }
        reply(error);
    }];
}

- (void)checkRepoStatus:(id)sender
{
    if (sender || !_checkStatusTimeStamp || [_checkStatusTimeStamp timeIntervalSinceNow] <= 0) {

        // So we don't constantly hit the network at the exact same time, space it out the git calls.
        NSTimeInterval interval = arc4random_uniform(600) + 300;
        _checkStatusTimeStamp = [NSDate dateWithTimeIntervalSinceNow:interval];
        NSString *path = self.path;

        if (path) {
            NSArray *locTaskArgs = @[ @"rev-parse", self.defaultBranch ];
            NSArray *remTaskArgs = @[ @"ls-remote", @"--heads", @"origin", @"./.", self.defaultBranch ];

            [LGGitIntegration gitTaskWithArguments:locTaskArgs repoPath:path reply:^(NSString *locStdOut, NSError *error) {
                if (error) {
                    NSLog(@"Git Error: %@", error );
                }

                NSString *localSHA1 = locStdOut.trimmed;
                [LGGitIntegration gitTaskWithArguments:remTaskArgs repoPath:path reply:^(NSString *remStdOut, NSError *error) {
                    if (error) {
                        NSLog(@"Git Error: %@", error );
                    }

                    NSString *remoteSHA1 = remStdOut.split_bySpace.firstObject;
                    if (!remoteSHA1) {
                        _checkStatusTimeStamp = [NSDate dateWithTimeIntervalSinceNow:10];
                    } else if ([localSHA1 isEqualToString:remoteSHA1]) {
                        [self statusDidChange:kLGAutoPkgRepoUpToDate];
                    } else {
                        [self statusDidChange:kLGAutoPkgRepoUpdateAvailable];
                    }

//                    DevLog(@"%@ - %@ vs %@ : Status = %d", self.name, localSHA1.length ? [localSHA1 substringToIndex:7] : nil, remoteSHA1.length ? [remoteSHA1 substringToIndex:7] : nil, _status);
                    [self statusDidChange:_status];
                }];
            }];
        } else {
            [self statusDidChange:kLGAutoPkgRepoNotInstalled];
        }
    } else {
        [self statusDidChange:_status];
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
        NSMutableArray *commonRepos = [_popularRepos mutableCopy];

        [_activeRepos enumerateObjectsUsingBlock:^(NSDictionary *activeRepo, NSUInteger idx, BOOL *stop) {

            NSPredicate *pred = [NSPredicate predicateWithFormat:@"%K.absoluteString == %@",
                                 NSStringFromSelector(@selector(cloneURL)),
                                 activeRepo[kLGAutoPkgRepoURLKey]];

            if ([_popularRepos filteredArrayUsingPredicate:pred].count == 0) {
                LGAutoPkgRepo *repo = nil;
                if ((repo = [[self alloc] initWithAutoPkgDictionary:activeRepo])) {
                    [commonRepos addObject:repo];
                }
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
    } else {
        NSURL *url = [NSURL URLWithString:kLGAutoPkgRepositoriesJSONURL];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];

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
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSArray *fallbackRepos = @[ @"https://github.com/autopkg/recipes.git",
                                        @"https://github.com/autopkg/keeleysam-recipes.git",
                                        @"https://github.com/autopkg/hjuutilainen-recipes.git",
                                        @"https://github.com/autopkg/timsutton-recipes.git",
                                        @"https://github.com/autopkg/nmcspadden-recipes.git",
                                        @"https://github.com/autopkg/jleggat-recipes.git",
                                        @"https://github.com/autopkg/jaharmi-recipes.git",
                                        @"https://github.com/autopkg/jessepeterson-recipes.git",
                                        @"https://github.com/autopkg/dankeller-recipes.git",
                                        @"https://github.com/autopkg/hansen-m-recipes.git",
                                        @"https://github.com/autopkg/scriptingosx-recipes.git",
                                        @"https://github.com/autopkg/derak-recipes.git",
                                        @"https://github.com/autopkg/sheagcraig-recipes.git",
                                        @"https://github.com/autopkg/arubdesu-recipes.git",
                                        @"https://github.com/autopkg/jps3-recipes.git",
                                        @"https://github.com/autopkg/joshua-d-miller-recipes.git",
                                        @"https://github.com/autopkg/gerardkok-recipes.git",
                                        @"https://github.com/autopkg/swy-recipes.git",
                                        @"https://github.com/autopkg/lashomb-recipes.git",
                                        @"https://github.com/autopkg/rustymyers-recipes.git",
                                        @"https://github.com/autopkg/luisgiraldo-recipes.git",
                                        @"https://github.com/autopkg/justinrummel-recipes.git",
                                        @"https://github.com/autopkg/n8felton-recipes.git",
                                        @"https://github.com/autopkg/groob-recipes.git",
                                        @"https://github.com/autopkg/jazzace-recipes.git",
                                        ];

            NSMutableArray *popularRepos = [[NSMutableArray alloc] initWithCapacity:fallbackRepos.count];
            [fallbackRepos enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                LGAutoPkgRepo *repo = nil;
                if((repo = [[LGAutoPkgRepo alloc] initWithCloneURL:obj])){
                    [popularRepos addObject:repo];
                }
            }];
            _popularRepos = [popularRepos copy];
            constructCommonRepos();
        }];
        [op start];
    }
}

@end
