//
//  LGAutoPkgRecipe.m
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

#import "LGAutoPkgRecipe.h"
#import "LGAutoPkgRecipeListManager.h"
#import "LGAutoPkgTask.h"
#import "LGLogger.h"

#import <glob.h>

// MakeCatalogs recipe identifier string.
static NSString *const kLGMakeCatalogsRecipeName = @"MakeCatalogs.munki";
static NSString *const kLGMakeCatalogsIdentifier = @"com.github.autopkg.munki.makecatalogs";
static NSString *const kLGAutoPkgPythonPath = @"/usr/local/autopkg/python";

// Dispatch queue for enabling / disabling recipe.
static dispatch_queue_t autopkgr_recipe_write_queue()
{
    static dispatch_queue_t autopkgr_recipe_write_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        autopkgr_recipe_write_queue = dispatch_queue_create("com.lindegroup.autopkgr.recipe.write.queue", DISPATCH_QUEUE_SERIAL);
    });

    return autopkgr_recipe_write_queue;
}

static NSMutableDictionary *_identifierURLStore = nil;
static NSMutableDictionary *_recipeDictionaryCache = nil;

static NSString *LGRecipeNameFromURL(NSURL *recipeURL)
{
    NSString *fileName = recipeURL.lastPathComponent;
    NSString *lowercaseFileName = fileName.lowercaseString;
    for (NSString *extension in @[ @".recipe.yaml", @".recipe.plist", @".recipe" ]) {
        if ([lowercaseFileName hasSuffix:extension]) {
            return [fileName substringToIndex:fileName.length - extension.length];
        }
    }
    return [fileName stringByDeletingPathExtension];
}

static NSString *LGRecipeDictionaryCacheKey(NSURL *recipeURL)
{
    NSString *path = recipeURL.path;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSDate *modificationDate = attributes[NSFileModificationDate];
    NSNumber *fileSize = attributes[NSFileSize];

    if (!path.length || !modificationDate || !fileSize) {
        return nil;
    }

    return [NSString stringWithFormat:@"%@:%@:%@", path, @([modificationDate timeIntervalSinceReferenceDate]), fileSize];
}

static BOOL LGRecipeURLIsYAMLRecipe(NSURL *recipeURL)
{
    return [recipeURL.lastPathComponent.lowercaseString hasSuffix:@".recipe.yaml"];
}

static NSArray *LGYAMLRecipeURLsRecursivelyAtPath(NSString *path)
{
    NSMutableArray *recipeURLs = [[NSMutableArray alloc] init];

    if (path && (access(path.UTF8String, F_OK) == 0)) {
        NSString *matches = [NSString stringWithFormat:@"{%@/{*.recipe.yaml,*/*.recipe.yaml}}", path];

        glob_t results;
        glob(matches.UTF8String, GLOB_BRACE | GLOB_NOSORT, NULL, &results);
        for (int i = 0; i < results.gl_matchc; i++) {
            NSString *globPath = [NSString stringWithUTF8String:results.gl_pathv[i]];
            NSURL *fileURL = [NSURL fileURLWithPath:globPath isDirectory:NO];

            if (fileURL) {
                [recipeURLs addObject:fileURL];
            }
        }
        globfree(&results);
    }

    return [recipeURLs copy];
}

#pragma mark - Recipes
//////////////////////////////////////////////////////////////////////////
// Recipes                                                             ///
//////////////////////////////////////////////////////////////////////////

@implementation LGAutoPkgRecipe {
@private
    /* This is the actual iVar used for the `enabled` property
     * which when initialize is -1. We then check for that value
     * during the -enabled getter and know if we need to do a more
     * expensive check that initializes an array */
    OSStatus _enabledInitialized;
    NSURL *_recipeFileURL;
}

@synthesize Description = _Description, MinimumVersion = _MinimumVersion;

+ (NSDictionary *)dictionariesFromYAMLRecipeURLs:(NSArray *)recipeURLs
{
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    NSMutableDictionary *recipeDictionariesByPath = [[NSMutableDictionary alloc] init];
    NSMutableArray *pathsToParse = [[NSMutableArray alloc] init];
    NSMutableDictionary *cacheKeysByPath = [[NSMutableDictionary alloc] init];

    for (NSURL *recipeURL in recipeURLs) {
        if (!LGRecipeURLIsYAMLRecipe(recipeURL) || !recipeURL.path.length) {
            continue;
        }

        NSString *cacheKey = LGRecipeDictionaryCacheKey(recipeURL);
        if (cacheKey) {
            @synchronized(self) {
                NSDictionary *cachedRecipe = _recipeDictionaryCache[cacheKey];
                if (cachedRecipe) {
                    recipeDictionariesByPath[recipeURL.path] = cachedRecipe;
                    continue;
                }
            }
            cacheKeysByPath[recipeURL.path] = cacheKey;
        }

        [pathsToParse addObject:recipeURL.path];
    }

    NSUInteger cachedRecipeCount = recipeDictionariesByPath.count;
    if (!pathsToParse.count || ![[NSFileManager defaultManager] isExecutableFileAtPath:kLGAutoPkgPythonPath]) {
        LGLaunchProfileLog(@"YAML recipe batch skipped parse requested=%lu cached=%lu elapsed=%.3fs",
                           (unsigned long)recipeURLs.count,
                           (unsigned long)cachedRecipeCount,
                           [NSDate timeIntervalSinceReferenceDate] - startTime);
        return [recipeDictionariesByPath copy];
    }

    LGLaunchProfileLog(@"YAML recipe batch parse start requested=%lu toParse=%lu cached=%lu",
                       (unsigned long)recipeURLs.count,
                       (unsigned long)pathsToParse.count,
                       (unsigned long)cachedRecipeCount);

    NSData *inputData = [NSPropertyListSerialization dataWithPropertyList:pathsToParse
                                                                    format:NSPropertyListXMLFormat_v1_0
                                                                   options:0
                                                                     error:nil];
    if (!inputData) {
        LGLaunchProfileLog(@"YAML recipe batch parse aborted; failed to serialize path list elapsed=%.3fs",
                           [NSDate timeIntervalSinceReferenceDate] - startTime);
        return [recipeDictionariesByPath copy];
    }

    NSString *script = @"import plistlib\n"
                       @"import sys\n"
                       @"import yaml\n"
                       @"try:\n"
                       @"    sys.path.insert(0, \"/Library/AutoPkg\")\n"
                       @"    from autopkglib.autopkgyaml import AutoPkgYAMLLoader\n"
                       @"except Exception:\n"
                       @"    class AutoPkgYAMLLoader(yaml.SafeLoader):\n"
                       @"        pass\n"
                       @"    AutoPkgYAMLLoader.yaml_implicit_resolvers = AutoPkgYAMLLoader.yaml_implicit_resolvers.copy()\n"
                       @"    for first_letter, mappings in list(AutoPkgYAMLLoader.yaml_implicit_resolvers.items()):\n"
                       @"        AutoPkgYAMLLoader.yaml_implicit_resolvers[first_letter] = [\n"
                       @"            (tag, regexp) for tag, regexp in mappings\n"
                       @"            if tag != \"tag:yaml.org,2002:float\"\n"
                       @"        ]\n"
                       @"def plist_serializer(obj):\n"
                       @"    if isinstance(obj, dict):\n"
                       @"        for key, value in obj.items():\n"
                       @"            obj[key] = \"\" if value is None else plist_serializer(value)\n"
                       @"    elif isinstance(obj, list):\n"
                       @"        for index in range(len(obj)):\n"
                       @"            obj[index] = \"\" if obj[index] is None else plist_serializer(obj[index])\n"
                       @"    return obj\n"
                       @"recipes = {}\n"
                       @"for path in plistlib.loads(sys.stdin.buffer.read()):\n"
                       @"    try:\n"
                       @"        with open(path, \"rb\") as recipe_file:\n"
                       @"            recipe = yaml.load(recipe_file, Loader=AutoPkgYAMLLoader)\n"
                       @"        if not isinstance(recipe, dict):\n"
                       @"            continue\n"
                       @"        recipe = plist_serializer(recipe)\n"
                       @"        plistlib.dumps(recipe, fmt=plistlib.FMT_XML)\n"
                       @"        recipes[path] = recipe\n"
                       @"    except Exception:\n"
                       @"        pass\n"
                       @"sys.stdout.buffer.write(plistlib.dumps(recipes, fmt=plistlib.FMT_XML))\n";

    NSTask *task = [[NSTask alloc] init];
    task.launchPath = kLGAutoPkgPythonPath;
    task.arguments = @[ @"-c", script ];
    task.standardInput = [NSPipe pipe];
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSFileHandle fileHandleWithNullDevice];

    NSData *data = nil;
    @try {
        [task launch];
        [[task.standardInput fileHandleForWriting] writeData:inputData];
        [[task.standardInput fileHandleForWriting] closeFile];
        data = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
        [task waitUntilExit];
    }
    @catch (NSException *exception) {
        if (task.isRunning) {
            [task terminate];
        }
        LGLaunchProfileLog(@"YAML recipe batch parse exception %@ elapsed=%.3fs",
                           exception.name,
                           [NSDate timeIntervalSinceReferenceDate] - startTime);
        return [recipeDictionariesByPath copy];
    }

    if (task.terminationStatus != 0 || data.length == 0) {
        LGLaunchProfileLog(@"YAML recipe batch parse failed status=%d outputBytes=%lu elapsed=%.3fs",
                           task.terminationStatus,
                           (unsigned long)data.length,
                           [NSDate timeIntervalSinceReferenceDate] - startTime);
        return [recipeDictionariesByPath copy];
    }

    id recipes = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:nil
                                                             error:nil];
    if (![recipes isKindOfClass:[NSDictionary class]]) {
        LGLaunchProfileLog(@"YAML recipe batch parse returned non-dictionary elapsed=%.3fs",
                           [NSDate timeIntervalSinceReferenceDate] - startTime);
        return [recipeDictionariesByPath copy];
    }

    @synchronized(self) {
        if (!_recipeDictionaryCache) {
            _recipeDictionaryCache = [[NSMutableDictionary alloc] init];
        }
        [recipes enumerateKeysAndObjectsUsingBlock:^(id path, id recipe, BOOL *stop) {
            if (![recipe isKindOfClass:[NSDictionary class]]) {
                return;
            }

            NSString *cacheKey = cacheKeysByPath[path];
            if (cacheKey) {
                _recipeDictionaryCache[cacheKey] = recipe;
            }
            recipeDictionariesByPath[path] = recipe;
        }];
    }

    LGLaunchProfileLog(@"YAML recipe batch parse complete requested=%lu parsed=%lu cached=%lu elapsed=%.3fs",
                       (unsigned long)recipeURLs.count,
                       (unsigned long)[recipes count],
                       (unsigned long)cachedRecipeCount,
                       [NSDate timeIntervalSinceReferenceDate] - startTime);

    return [recipeDictionariesByPath copy];
}

+ (void)cacheDictionariesFromYAMLRecipesAtPaths:(NSArray *)paths
{
    NSMutableArray *recipeURLs = [[NSMutableArray alloc] init];

    for (NSString *path in paths) {
        [recipeURLs addObjectsFromArray:LGYAMLRecipeURLsRecursivelyAtPath(path)];
    }

    [[self class] dictionariesFromYAMLRecipeURLs:recipeURLs];
}

+ (NSDictionary *)dictionaryFromRecipeURL:(NSURL *)recipeURL
{
    if (!LGRecipeURLIsYAMLRecipe(recipeURL)) {
        // Standalone .yaml files aren't recipes; anything else is read as a plist.
        NSString *lowercaseName = recipeURL.lastPathComponent.lowercaseString;
        if ([lowercaseName hasSuffix:@".yaml"]) {
            return nil;
        }
        return [NSDictionary dictionaryWithContentsOfURL:recipeURL];
    }

    NSString *cacheKey = LGRecipeDictionaryCacheKey(recipeURL);
    if (cacheKey) {
        @synchronized(self) {
            NSDictionary *cachedRecipe = _recipeDictionaryCache[cacheKey];
            if (cachedRecipe) {
                return cachedRecipe;
            }
        }
    }

    NSString *path = recipeURL.path;
    return path.length ? [[self class] dictionariesFromYAMLRecipeURLs:@[ recipeURL ]][path] : nil;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Name: %@ Identifier: %@ Parent: %@", _Name, _Identifier, self.ParentRecipe];
}

- (instancetype)initWithRecipeFile:(NSURL *)recipeFile isOverride:(BOOL)isOverride
{
    // Don't initialize anything if we can't determine a recipe identifier.
    NSDictionary *reciptPlist = [[self class] dictionaryFromRecipeURL:recipeFile];
    id identifierValue = reciptPlist[kLGAutoPkgRecipeIdentifierKey] ?: reciptPlist[@"Input"][@"IDENTIFIER"];

    // YAML (or a malformed plist) can produce a non-string identifier (e.g. a
    // number), so reject anything that isn't a string to avoid crashing on -length.
    NSString *identifier = [identifierValue isKindOfClass:[NSString class]] ? identifierValue : nil;

    if (identifier.length && (self = [super init])) {
        _recipePlist = reciptPlist;
        _Identifier = identifier;

        _recipeFileURL = recipeFile;
        _Name = LGRecipeNameFromURL(recipeFile);

        _FilePath = recipeFile.path;
        _isOverride = isOverride;
        _enabledInitialized = -1;

        [_identifierURLStore setObject:_recipeFileURL forKey:_Identifier];
        return self;
    }
    return nil;
}

- (NSString *)Description
{
    return [self stringValueForKey:NSStringFromSelector(_cmd)];
}

- (NSString *)MinimumVersion
{
    return [self stringValueForKey:NSStringFromSelector(_cmd)];
}

// These accessors are declared to return NSString * and feed
// NSTextField.safe_stringValue (which sends -length), but YAML (or a malformed
// plist) can yield a non-string scalar — e.g. `MinimumVersion: 3` parses as an
// NSNumber. Coerce numbers to strings and reject other non-string types so we
// never hand back something that crashes on -length.
- (NSString *)stringValueForKey:(NSString *)key
{
    id value = _recipePlist[key] ?: [self objectForKey:key ofIdentifier:self.ParentRecipe];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return nil;
}

- (NSString *)ParentRecipe
{
    // YAML (or a malformed plist) can produce a non-string ParentRecipe value;
    // only treat an actual non-empty string as a valid parent identifier.
    id parentRecipe = _recipePlist[kLGAutoPkgRecipeParentKey];
    if ([parentRecipe isKindOfClass:[NSString class]] && [parentRecipe length]) {
        return parentRecipe;
    }
    return nil;
}

- (NSArray *)ParentRecipes
{
    NSMutableArray *parents;
    NSString *parentRecipeID = self.ParentRecipe;

    if (parentRecipeID) {
        // Don't back this up with an iVar since when new recipe repos are
        // added this could actually trace the origin further back.
        parents = [NSMutableArray arrayWithObject:parentRecipeID];

        while (true) {
            NSURL *parentRecipeURL = [_identifierURLStore objectForKey:parentRecipeID];
            if (parentRecipeURL) {
                NSDictionary *recipePlist = [[self class] dictionaryFromRecipeURL:parentRecipeURL];
                id parentRecipeValue = recipePlist[kLGAutoPkgRecipeParentKey];
                // A non-string parent identifier (possible with YAML or a
                // malformed plist) ends the chain rather than crashing on -length.
                parentRecipeID = [parentRecipeValue isKindOfClass:[NSString class]] ? parentRecipeValue : nil;
                if (parentRecipeID.length) {
                    [parents addObject:parentRecipeID];
                }
                else {
                    break;
                }
            }
            else {
                break;
            }
        }
    }
    return [parents copy];
}

- (BOOL)isMissingParent
{
    if (self.ParentRecipe) {
        return ([_identifierURLStore objectForKey:self.ParentRecipe] == nil);
    }
    return NO;
}

- (BOOL)recipeConfigError
{
    return self.isMissingParent;
}

- (NSDictionary *)Input
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

- (NSArray *)Process
{
    return _recipePlist[NSStringFromSelector(_cmd)];
}

#pragma mark - Enabled
- (void)enableRecipe:(NSButton *)sender
{
    if ([sender isKindOfClass:[NSButton class]]) {
        self.enabled = sender.state;
        // Double check that enabling of the recipe was successful.
        BOOL state = [[[self class] activeRecipes] containsObject:self.Identifier];
        dispatch_async(dispatch_get_main_queue(), ^{
            // Update the UI on the main thread.
            sender.state = state;
        });
    }
}

- (BOOL)isEnabled
{
    if (_enabledInitialized == -1) {
        _enabledInitialized = [[[self class] activeRecipes] containsObject:self.Identifier];
    }
    return _enabledInitialized;
}

- (void)setEnabled:(BOOL)enabled
{
    /* We automatically handle the enabling of the MakeCatalogs recipe
     * so don't do anything if that's the one getting enabled. */
    if ([self.Name isEqualToString:kLGMakeCatalogsRecipeName]) {
        return;
    }

    /* This is all dispatched to a serial queue so a race condition doesn't raise
     * when multiple recipes are added or removed in rapid succession. */
    dispatch_sync(autopkgr_recipe_write_queue(), ^{
        NSError *error;

        __block NSMutableArray *currentList = [[NSMutableArray alloc] init];

        NSString *recipeListFile = [[self class] defaultRecipeList];
        NSString *fileContents = [NSString stringWithContentsOfFile:recipeListFile encoding:NSUTF8StringEncoding error:nil];

        /* Get the recipe list, split it by lines, and turn it into an array. */
        NSArray *existingList;
        if ((existingList = fileContents.split_byLine.filtered_noEmptyStrings)) {
            [currentList addObjectsFromArray:existingList];
        }

        /* Start by removing any instance of MakeCatalogs from the list. It's added back in later. */
        NSPredicate *makeCatalogPredicate = [NSPredicate predicateWithFormat:@"SELF contains[cd] 'MakeCatalogs'"];
        [currentList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([makeCatalogPredicate evaluateWithObject:obj]) {
                [currentList removeObject:obj];
            }
        }];

        if (enabled) {
            if (![currentList containsObject:self.Identifier]) {
                [currentList insertObject:self.Identifier atIndex:0];
            }
        }
        else {
            [currentList removeObject:self.Identifier];
        }

        /* Enumerate over the list to see if there are any .munki recipes
         * now listed. If so re-add the MakeCatalogs recipe. */
        [currentList enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj rangeOfString:@"munki"].location != NSNotFound) {
                [currentList addObject:kLGMakeCatalogsRecipeName];
                *stop = YES;
            }
        }];

        NSString *recipe_list = [currentList componentsJoinedByString:@"\n"];
        if (![recipe_list writeToFile:recipeListFile atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            NSLog(@"Error while writing %@. %@", recipeListFile, error);
            return;
        }

        currentList = nil;
        _enabledInitialized = enabled;
    });
}

#pragma mark - Checks
- (BOOL)hasStepProcessor:(NSString *)step
{
    NSMutableArray *considered = [NSMutableArray arrayWithObject:_recipePlist];

    for (NSString *identifier in self.ParentRecipes) {
        NSDictionary *plist = [self recipePlistForIdentifier:identifier];
        if (plist) {
            [considered addObject:plist];
        }
    }

    for (NSDictionary *plist in considered) {
        NSArray *processes = plist[kLGAutoPkgRecipeProcessKey];
        if (processes) {
            if ([processes indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
                    return [obj[@"Processor"] isEqualToString:step];
                }]
                != NSNotFound) {
                return YES;
            }
        }
    };

    return NO;
}

- (BOOL)hasCheckPhase
{
    return [self hasStepProcessor:@"EndOfCheckPhase"];
}

- (BOOL)buildsPackage
{
    return [self hasStepProcessor:@"PkgCreator"];
}

#pragma mark - Value retrieval
- (NSDictionary *)recipePlistForIdentifier:(NSString *)identifier
{
    NSURL *recipeURL = [_identifierURLStore objectForKey:identifier];
    if (recipeURL) {
        return [[self class] dictionaryFromRecipeURL:recipeURL];
    }
    return nil;
}

- (id)objectForKey:(NSString *)key ofIdentifier:(NSString *)identifier
{
    return [self recipePlistForIdentifier:identifier][key];
}

#pragma mark - Class Methods;
+ (NSArray *)allRecipes
{
    return [[self class] allRecipesFilteringOverlaps:NO];
}

+ (NSArray *)allRecipesFilteringOverlaps:(BOOL)filterOverlaps
{
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    LGLaunchProfileLog(@"allRecipes scan start filterOverlaps=%@", filterOverlaps ? @"YES" : @"NO");

    _identifierURLStore = [[NSMutableDictionary alloc] init];
    @synchronized(self) {
        _recipeDictionaryCache = [[NSMutableDictionary alloc] init];
    }
    LGDefaults *defaults = [LGDefaults standardUserDefaults];

    NSMutableArray *allRecipes = [[NSMutableArray alloc] init];
    NSSet *activeRecipes = [self activeRecipes];

    NSArray *searchDirs = defaults.autoPkgRecipeSearchDirs;
    NSMutableArray *recipeSearchPaths = [[NSMutableArray alloc] init];
    for (NSString *searchDir in searchDirs) {
        if (![searchDir isEqualToString:@"."]) {
            [recipeSearchPaths addObject:searchDir.stringByExpandingTildeInPath];
        }
    }

    // Expand the whole expression: the overrides dir read from AutoPkg's prefs
    // may contain a "~", and it's later used with access()/glob() (which don't
    // expand tildes) during the YAML preload below.
    NSString *recipeOverridePath = (defaults.autoPkgRecipeOverridesDir ?: @"~/Library/AutoPkg/RecipeOverrides").stringByExpandingTildeInPath;
    [recipeSearchPaths addObject:recipeOverridePath];
    [self cacheDictionariesFromYAMLRecipesAtPaths:recipeSearchPaths];
    LGLaunchProfileLog(@"allRecipes YAML preload complete paths=%lu", (unsigned long)recipeSearchPaths.count);

    for (NSString *searchDir in searchDirs) {
        if (![searchDir isEqualToString:@"."]) {
            NSArray *recipeArray = [self findRecipesRecursivelyAtPath:searchDir.stringByExpandingTildeInPath isOverride:NO activeRecipes:activeRecipes];
            if (recipeArray.count) {
                [allRecipes addObjectsFromArray:recipeArray];
            }
        }
    }
    LGLaunchProfileLog(@"allRecipes repo scan complete count=%lu", (unsigned long)allRecipes.count);

    NSArray *overrideArray = [self findRecipesRecursivelyAtPath:recipeOverridePath isOverride:YES activeRecipes:activeRecipes];
    LGLaunchProfileLog(@"allRecipes override scan complete count=%lu", (unsigned long)overrideArray.count);
    NSMutableArray *validOverrides = [[NSMutableArray alloc] init];

    for (LGAutoPkgRecipe * override in overrideArray) {
        // Only consider the recipe valid if the parent exists.
        NSPredicate *parentExistsPredicate = [NSPredicate predicateWithFormat:@"%K contains %@", kLGAutoPkgRecipeIdentifierKey, override.ParentRecipe];

        if ([parentExistsPredicate evaluateWithObject:allRecipes]) {
            [validOverrides addObject:override];
        }
    }

    if (filterOverlaps) {
        for (LGAutoPkgRecipe * override in validOverrides) {
            /* Filter the array by removing the parent recipe if an override is found that matches
             * BOTH conditions: the value for the "Name" key of the override is same as the value
             * for the "Name" key of the Parent AND the value for the Parent Recipe's "Identifier" key
             * is the same as the value for override's "ParentRecipe" key. */
            NSPredicate *overridePreferedPredicate = [NSPredicate predicateWithFormat:@"not (%K == %@ AND %K == %@)", kLGAutoPkgRecipeNameKey, override.Name, kLGAutoPkgRecipeIdentifierKey, override.ParentRecipe];

            [allRecipes filterUsingPredicate:overridePreferedPredicate];
        }
    }

    // Now add the valid overrides into the recipeArray.
    if (validOverrides.count) {
        [allRecipes addObjectsFromArray:validOverrides];
    }

    // Make a sorted array using the recipe name as the sort key.
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:kLGAutoPkgRecipeNameKey
                                                               ascending:YES];

    [allRecipes sortUsingDescriptors:@[ descriptor ]];
    LGLaunchProfileLog(@"allRecipes scan complete count=%lu elapsed=%.3fs",
                       (unsigned long)allRecipes.count,
                       [NSDate timeIntervalSinceReferenceDate] - startTime);

    validOverrides = nil;

    return allRecipes.count ? [allRecipes copy] : nil;
}

+ (NSArray *)findRecipesRecursivelyAtPath:(NSString *)path isOverride:(BOOL)isOverride activeRecipes:(NSSet *)activeRecipes
{
    NSMutableArray *recipes = [[NSMutableArray alloc] init];
    if (!_identifierURLStore) {
        _identifierURLStore = [[NSMutableDictionary alloc] init];
    }

    if (path && (access(path.UTF8String, F_OK) == 0)) {
        NSString *matches = [NSString stringWithFormat:@"{%@/{*.recipe,*/*.recipe,*.recipe.yaml,*/*.recipe.yaml,*.plist,*/*.plist}}", path];

        glob_t results;
        glob(matches.UTF8String, GLOB_BRACE | GLOB_NOSORT, NULL, &results);
        NSMutableArray *yamlRecipeURLs = [[NSMutableArray alloc] init];
        for (int i = 0; i < results.gl_matchc; i++) {
            NSString *globPath = [NSString stringWithUTF8String:results.gl_pathv[i]];
            NSURL *fileURL = [NSURL fileURLWithPath:globPath isDirectory:NO];

            if (LGRecipeURLIsYAMLRecipe(fileURL)) {
                [yamlRecipeURLs addObject:fileURL];
            }
        }

        [[self class] dictionariesFromYAMLRecipeURLs:yamlRecipeURLs];

        for (int i = 0; i < results.gl_matchc; i++) {
            NSString *globPath = [NSString stringWithUTF8String:results.gl_pathv[i]];
            NSURL *fileURL = [NSURL fileURLWithPath:globPath isDirectory:NO];

            if (fileURL) {
                LGAutoPkgRecipe *recipe = [[LGAutoPkgRecipe alloc] initWithRecipeFile:fileURL isOverride:isOverride];
                if (recipe) {
                    [recipes addObject:recipe];
                    // If it's in the active recipe list, mark it as enabled.
                    if (activeRecipes) {
                        if ([activeRecipes containsObject:recipe.Identifier]) {
                            recipe->_enabledInitialized = YES;
                        }
                        else {
                            recipe->_enabledInitialized = NO;
                        }
                    }
                }
            }
        }
        globfree(&results);
    }

    return [recipes copy];
}

+ (NSOrderedSet *)activeRecipes
{
    NSError *error;
    NSMutableOrderedSet *activeRecipes = [[NSMutableOrderedSet alloc] init];

    NSString *recipeList = [self defaultRecipeList];
    if (recipeList) {
        NSString *autoPkgrRecipeList = [NSString stringWithContentsOfFile:recipeList encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            NSLog(@"Error reading %@.", autoPkgrRecipeList);
        }
        else {
            NSArray *recipes = autoPkgrRecipeList.split_byLine;
            if (recipes.count) {
                [activeRecipes addObjectsFromArray:recipes];
            }
        }
    }

    return [activeRecipes copy];
}

#pragma mark - Util
+ (NSString *)defaultRecipeList
{
    return [[LGAutoPkgRecipeListManager new] currentListPath];
}

+ (BOOL)removeRecipeFromRecipeList:(NSString *)recipe
{
    NSError *error;
    NSMutableOrderedSet *recipes = [[LGAutoPkgRecipe activeRecipes] mutableCopy];
    [recipes removeObject:recipe];

    NSString *recipe_list = [recipes.array componentsJoinedByString:@"\n"];
    if (![recipe_list writeToFile:[self defaultRecipeList] atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        NSLog(@"Error writing file: %@", error.localizedDescription);
        return NO;
    }
    return YES;
}

+ (BOOL)migrateToIdentifiers:(NSError *__autoreleasing *)error
{
    NSFileManager *manager = [[NSFileManager alloc] init];
    NSString *orig = [[self class] defaultRecipeList];

    LGDefaults *defaults = [LGDefaults new];
    BOOL check1 = [defaults boolForKey:@"MigratedToIdentifiers"];

    BOOL check2 = [manager fileExistsAtPath:orig];

    if (check1 || !check2) {
        [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
        return YES;
    }

    NSLog(@"Prompting user to upgrade recipe list to new identifier format...");

    NSString *infoText = @"AutoPkgr now uses recipe identifiers instead of short names to specify recipes. This makes it possible to schedule and run identically-named recipes from separate repos.";

    NSAlert *alert = [NSAlert alertWithMessageText:@"AutoPkgr needs to convert your recipe list."
                                     defaultButton:@"Upgrade"
                                   alternateButton:@"Quit"
                                       otherButton:nil
                         informativeTextWithFormat:@"%@", infoText];

    if ([alert runModal] == NSAlertDefaultReturn) {

        NSLog(@"Permission granted. Upgrading recipe list...");
        NSString *bak = [orig stringByAppendingPathExtension:@"v1.bak"];
        if ([manager fileExistsAtPath:orig] && ![manager fileExistsAtPath:bak]) {
            [manager copyItemAtPath:orig toPath:bak error:nil];
        }

        // Migrate preferences.
        __block int i = 0; // Number of changed recipes.
        NSArray *recipes = [self allRecipes];
        NSArray *activeRecipes = [[self activeRecipes] copy];

        [activeRecipes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            for (LGAutoPkgRecipe *recipe in recipes) {
                if ([recipe.Name isEqualToString:obj]) {
                    recipe.enabled = YES;
                    i++;
                }
            }
        }];

        BOOL success = (i == activeRecipes.count);
        [defaults setBool:YES forKey:@"MigratedToIdentifiers"];
        // Return NO if any were unable to be converted.
        if (!success) {
            NSLog(@"An error may have occurred while converting the recipe list. We successfully converted %d out of %lu recipes. However it's also possible your recipe list was already converted. Please double check your enabled recipes now.", i, (unsigned long)activeRecipes.count);
        }
        else {
            NSLog(@"The recipe list was upgraded successfully.");
        }
        return YES;
    }
    NSLog(@"User chose not to upgrade recipe list.");
    return NO;
}
@end
