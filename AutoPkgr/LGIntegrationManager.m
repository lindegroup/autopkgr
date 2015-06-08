// LGIntegrationsStatus.m
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

#import "LGIntegrationManager.h"
#import "NSArray+filtered.h"

static NSArray *__integrationClasses;
static NSArray *__optionalIntegrationClasses;
static NSArray *__requiredIntegrationClasses;

@implementation LGIntegrationManager
@synthesize allIntegrations = _allIntegrations, optionalIntegrations = _optionalIntegrations, requiredIntegrations = _requiredIntegrations, installedIntegrations = _installedIntegrations;

+ (void)load
{
    // At +load create what are essentially static const arrays.
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        // As needed add additional integrations to this array.
        __integrationClasses = @[
                          [LGAutoPkgIntegration class],
                          [LGGitIntegration class],
                          [LGMunkiIntegration class],
                          [LGJSSImporterIntegration class],
                          [LGAbsoluteManageIntegration class],
                          ];

        __requiredIntegrationClasses = @[
                            [LGGitIntegration class],
                            [LGAutoPkgIntegration class],
                            ];


        /* The optional integrations will be everything after the first two
         * This should grow as AutoPkgr starts handling a wider scope 
         * of integrations and this should eliminate having to continuously modifying this. */
        NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(__requiredIntegrationClasses.count, (__integrationClasses.count)-(__requiredIntegrationClasses.count))];

        __optionalIntegrationClasses = [__integrationClasses objectsAtIndexes:idxSet];
    });
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kLGNotificationIntegrationStatusDidChange object:nil];
}

- (instancetype)init
{
    if (self = [super init]) {

        NSNotificationCenter *ndc = [NSNotificationCenter defaultCenter];
        NSMutableArray *initedIntegrations = [NSMutableArray arrayWithCapacity:__integrationClasses.count];

        for (Class integrationClass in __integrationClasses) {
            id integration = nil;
            if ((integration = [[integrationClass alloc] init])) {
                [initedIntegrations addObject:integration];

                // Add a notification for changes to the integration.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [ndc addObserver:self
                            selector:@selector(installStatusDidChange:)
                                name:kLGNotificationIntegrationStatusDidChange
                              object:integration];
                });
            }
        }
        _allIntegrations = [initedIntegrations copy];
    }
    return self;
}

- (void)installStatusDidChange:(NSNotification *)aNotification
{
    _installedIntegrations = nil;
    _installStatusDidChangeHandler(self, aNotification.object);
}

- (NSArray *)installedIntegrations
{
    if (!_installedIntegrations) {

        NSMutableArray *installedIntegrations = nil;
        for (LGIntegration *integration in self.allIntegrations) {
            if (installedIntegrations || (installedIntegrations = [NSMutableArray new])) {
                if ([[integration class] isInstalled]) {
                    [installedIntegrations addObject:integration];
                }
            }
        }
        _installedIntegrations = [installedIntegrations copy];
    }
    return _installedIntegrations;
}

- (NSArray *)installedOrRequiredIntegrations
{
    NSMutableOrderedSet *set = [NSMutableOrderedSet orderedSetWithArray:self.requiredIntegrations];
    [set addObjectsFromArray:self.installedIntegrations];
    return set.array;
}

- (NSArray *)optionalIntegrations
{
    if (!_optionalIntegrations) {
        NSMutableArray *optionalIntegrations = nil;
        for (LGIntegration *integration in self.allIntegrations) {
            if (optionalIntegrations || (optionalIntegrations = [NSMutableArray new])) {
                if ([__optionalIntegrationClasses containsObject:[integration class]]) {
                    [optionalIntegrations addObject:integration];
                }
            }
        }
        _optionalIntegrations = [optionalIntegrations copy];
    }
    return _optionalIntegrations;
}

- (NSArray *)requiredIntegrations
{
    if (!_requiredIntegrations) {
        NSMutableArray *requiredIntegration = nil;
        for (LGIntegration *integration in self.allIntegrations) {
            if (requiredIntegration || (requiredIntegration = [NSMutableArray new])) {
                if ([__requiredIntegrationClasses containsObject:[integration class]]) {
                    [requiredIntegration addObject:integration];
                }
            }
        }
        _requiredIntegrations = [requiredIntegration copy];
    }
    return _requiredIntegrations;
}

#pragma mark - Class Methods
- (id)integrationOfClass:(Class)integrationClass
{
    return [self.allIntegrations filteredArrayByClass:integrationClass].firstObject;
}

+ (BOOL)requiredItemsInstalled
{
    for (Class integrationClass in __requiredIntegrationClasses) {
        if (![integrationClass isInstalled]) {
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