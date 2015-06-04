// LGToolsStatus.m
//
//  Copyright 2015 Eldon Ahrold.
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

#import "LGToolManager.h"
#import "NSArray+filtered.h"

static NSArray *__toolClasses;
static NSArray *__optionalToolsClasses;
static NSArray *__requiredToolsClasses;

@implementation LGToolManager
@synthesize allTools = _allTools, optionalTools = _optionalTools, requiredTools = _requiredTools, installedTools = _installedTools;


+ (void)load
{
    // At +load create what are essentially static const arrays.
    static dispatch_once_t allToolsToken;
    dispatch_once(&allToolsToken, ^{
        // As needed add additional tools to this array.
        __toolClasses = @[
                          [LGAutoPkgTool class],
                          [LGGitTool class],
                          [LGMunkiTool class],
                          [LGJSSImporterTool class],
                          ];

        __requiredToolsClasses = @[
                            [LGGitTool class],
                            [LGAutoPkgTool class],
                            ];


        /* The optional tools will be everything after the first two
         * This should grow as AutoPkgr starts handling a wider scope 
         * of tools and this should eliminate having to continuously modifying this. */
        NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(__requiredToolsClasses.count, (__toolClasses.count)-(__requiredToolsClasses.count))];

        __optionalToolsClasses = [__toolClasses objectsAtIndexes:idxSet];
    });
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLGNotificationToolStatusDidChange object:nil];
}

- (instancetype)init {
    if (self = [super init]) {

        NSNotificationCenter *ndc = [NSNotificationCenter defaultCenter];
        NSMutableArray *initedTools = [NSMutableArray arrayWithCapacity:__toolClasses.count];

        for (Class toolClass in __toolClasses) {
            id tool = nil;
            if ((tool = [[toolClass alloc] init])) {
                [initedTools addObject:tool];

                // Add a notification for changes to the tool.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [ndc addObserver:self
                            selector:@selector(installStatusDidChange:)
                                name:kLGNotificationToolStatusDidChange
                              object:tool];
                });

            }
        }
        _allTools = [initedTools copy];

    }
    return self;
}

- (void)installStatusDidChange:(NSNotification *)aNotification {
    _installedTools = nil;

    _installStatusDidChangeHandler(aNotification.object, [self.installedTools indexOfObject:aNotification.object]);
}

- (NSArray *)installedTools
{
    if (!_installedTools) {

        NSMutableArray *installedTools = nil;
        for (LGTool *tool in self.allTools) {
            if (installedTools || (installedTools = [NSMutableArray new])){
                if ([[tool class] isInstalled]) {
                    [installedTools addObject:tool];
                }
            }
        }
        _installedTools = [installedTools copy];
    }
    return _installedTools;
}

- (NSArray *)installedOrRequiredTools
{
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:self.requiredTools];
    [set addObjectsFromArray:self.installedTools];
    return set.array;
}

- (NSArray *)optionalTools
{
    if (!_optionalTools) {
        NSMutableArray *optionalTools = nil;
        for (LGTool *tool in self.allTools) {
            if (optionalTools || (optionalTools = [NSMutableArray new])){
                if ([__optionalToolsClasses containsObject:[tool class]]) {
                    [optionalTools addObject:tool];
                }
            }
        }
        _optionalTools = [optionalTools copy];
    }
    return _optionalTools;
}

- (NSArray *)requiredTools
{
    if (!_requiredTools) {
        NSMutableArray *requiredTool = nil;
        for (LGTool *tool in self.allTools) {
            if (requiredTool || (requiredTool = [NSMutableArray new])){
                if ([__requiredToolsClasses containsObject:[tool class]]) {
                    [requiredTool addObject:tool];
                }
            }
        }
        _requiredTools = [requiredTool copy];
    }
    return _requiredTools;
}

#pragma mark - Class Methods
- (id)toolOfClass:(Class)toolClass {
    return [self.allTools filteredArrayByClass:toolClass].firstObject;
}

+ (BOOL)requiredItemsInstalled
{
    for (Class toolClass in __requiredToolsClasses) {
        if (![toolClass isInstalled]) {
            return NO;
        }
    }
    return YES;
}

+ (void)displayRequirementsAlertOnWindow:(NSWindow *)window
{
    NSAlert *alert = [NSAlert alertWithMessageText:@"Required components not installed."
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"AutoPkgr requires both AutoPkg and Git. Please install both before proceeding."];

    [alert beginSheetModalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
}

@end