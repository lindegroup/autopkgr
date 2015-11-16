//
//  LGJSSDistributionPoint.m
//  AutoPkgr
//
//  Created by Eldon on 11/9/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
//

#import "LGJSSDistributionPoint.h"
#import "LGJSSImporterIntegration.h"

#pragma mark - Key Dict
// Key used to indicate the array of required keys for a DP
const NSString *kRequired = @"required";

// Key used to indicate the array of optional keys for a DP
const NSString *kOptional = @"optional";

// Key used to indicate the array containing the keys used to
// determine whether the dp should be updated or inserted.
const NSString *kExclusiveUnique = @"unique";

// Key used to indicate the type string for the key
const NSString *kTypeString = @"typestr";

NSDictionary *keyInfoDict()
{
    static dispatch_once_t onceToken;
    __strong static NSDictionary *dictionary = nil;
    dispatch_once(&onceToken, ^{
        // Required keys common on remote mountable types (AFP / SMB)
        NSArray *mountable = @[
            kLGJSSDistPointTypeKey,
            kLGJSSDistPointSharePointKey,
            kLGJSSDistPointURLKey,
            kLGJSSDistPointUserNameKey,
            kLGJSSDistPointPasswordKey,
        ];
        dictionary = @{
            // Local
            @(kLGJSSTypeLocal) :
                @{ kTypeString: @"Local",
                   kRequired : @[ kLGJSSDistPointTypeKey,
                                  kLGJSSDistPointSharePointKey,
                                  kLGJSSDistPointMountPointKey ],
                   kOptional : @[],
                   kExclusiveUnique : @[ kLGJSSDistPointTypeKey ] },

            // SMB
            @(kLGJSSTypeSMB) :
                @{ kTypeString: @"SMB",
                   kRequired : mountable,
                   kOptional : @[ kLGJSSDistPointNameKey,
                                  kLGJSSDistPointPortKey,
                                  kLGJSSDistPointWorkgroupDomainKey ],
                   kExclusiveUnique : @[ kLGJSSDistPointURLKey ] },

            // AFP
            @(kLGJSSTypeAFP) :
                @{ kTypeString: @"AFP",
                   kRequired : mountable,
                   kOptional : @[ kLGJSSDistPointNameKey,
                                  kLGJSSDistPointPortKey ],
                   kExclusiveUnique : @[ kLGJSSDistPointURLKey ] },

            // JDS
            @(kLGJSSTypeJDS) :
                @{ kTypeString: @"JDS",
                   kRequired : @[ kLGJSSDistPointTypeKey ],
                   kOptional : @[],
                   kExclusiveUnique : @[ kLGJSSDistPointTypeKey ] },

            // CDP
            @(kLGJSSTypeCDP) :
                @{ kTypeString: @"CDP",
                   kRequired : @[ kLGJSSDistPointTypeKey ],
                   kOptional : @[],
                   kExclusiveUnique : @[ kLGJSSDistPointTypeKey ] },

            // From JSS
            @(kLGJSSTypeFromJSS) :
                @{ kRequired : @[ kLGJSSDistPointNameKey,
                                  kLGJSSDistPointPasswordKey ],
                   kOptional : @[],
                   kExclusiveUnique : @[ kLGJSSDistPointNameKey ] },
        };
    });
    return dictionary;
}

#pragma mark - LGJSSDistributionPoint
@implementation LGJSSDistributionPoint {
@private
    NSMutableDictionary *_dpDict;
}

+ (NSDictionary *)keyInfoDict {
    return keyInfoDict();
}

#pragma mark - Init
- (instancetype)init
{
    if ((self = [super init])) {
        _dpDict = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [super init])) {
        _dpDict = dict.mutableCopy;
    }
    return self;
}

- (instancetype)initWithType:(JSSDistributionPointType)type
{
    if ((self = [self init])) {
        self.type = type;
    }
    return self;
}

- (instancetype)initWithTypeString:(NSString *)typeString
{
    if ((self = [self init])) {
        self.typeString = typeString;
        NSAssert(self.type, @"Incorrect typeString passed in during initialization.");
    }
    return self;
}

#pragma mark - Util
- (void)setType:(JSSDistributionPointType)type
{
    NSString *typeString = keyInfoDict()[@(type)][kTypeString];
    if (typeString) {
        [_dpDict setObject:typeString forKey:kLGJSSDistPointTypeKey];
    }
}

- (JSSDistributionPointType)type
{
    NSString *type = [_dpDict[kLGJSSDistPointTypeKey] lowercaseString];
    NSDictionary *d = keyInfoDict();
    for (NSNumber *k in d){
        if ([[d[k][kTypeString] lowercaseString] isEqualToString:type]){
            return (JSSDistributionPointType)k.integerValue;
        }
    }
    assert(@"Correct type not determined.");
    return kLGJSSTypeFromJSS;
}

- (BOOL)validKeyForType:(NSString *)key
{
    // Type Keys is alwas valid
    if ([key isEqualToString:kLGJSSDistPointTypeKey]) {
        return YES;
    }

    NSNumber *type = @(self.type);
    NSDictionary *keys = keyInfoDict()[type];
    return ([keys[kRequired] containsObject:key] ||
            [keys[kOptional] containsObject:key]);
}

- (BOOL)hasRequiredKeys
{
    NSDictionary *keys = keyInfoDict()[@(self.type)];
    for (NSString *key in keys[kRequired]) {
        if (!_dpDict[key]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - Accesssors
#pragma mark-- Private --
- (void)updateValue:(NSString *)value forKey:(NSString *)key
{
    if ([self validKeyForType:key]) {
        if (value) {
            [_dpDict setObject:value forKey:key];
        } else {
            [_dpDict removeObjectForKey:key];
        }
    }
}

- (id)getValueForKey:(NSString *)key
{
    return [self validKeyForType:key] ? [_dpDict objectForKey:key] : nil;
}

#pragma mark-- Public --
- (NSString *)description {
    NSString *description = nil;
    NSString *type = self.typeString;

    switch (self.type) {
        case kLGJSSTypeFromJSS: {
            description = @"Pulled from JSS.";
            type = @"<Auto>";
            break;
        }
        case kLGJSSTypeAFP:
        case kLGJSSTypeSMB:
        case kLGJSSTypeLocal: {
            description = self.URL;
            break;
        }
        case kLGJSSTypeJDS:
        case kLGJSSTypeCDP:
        default: {
            break;
        }
    }

    if (description) {
        return [NSString stringWithFormat:@"%@ (%@)", type, description];
    }
    
    return self.typeString;
}
- (NSDictionary *)representation
{
    NSMutableDictionary *representation = [[NSMutableDictionary alloc] init];
    [_dpDict enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        id val = nil;
        if ((val = [self getValueForKey:key])) {
            representation[key] = val;
        }
    }];
    return representation;
}

- (NSString *)name
{
    if (self.type == kLGJSSTypeLocal) {
        return self.share_name;
    } else {
        return [self getValueForKey:NSStringFromSelector(@selector(name))];
    }
}

- (void)setName:(NSString *)name
{
    if (self.type == kLGJSSTypeLocal) {
        self.share_name = name;
    } else {
        [self updateValue:name forKey:NSStringFromSelector(@selector(name))];
    }
}

- (NSString *)URL
{
    if (self.type == kLGJSSTypeLocal) {
        return self.mount_point;
    } else {
        return [self getValueForKey:NSStringFromSelector(@selector(URL))];
    }
}

- (void)setURL:(NSString *)URL
{
    if (self.type == kLGJSSTypeLocal) {
        self.mount_point = URL;
    } else {
        [self updateValue:URL forKey:NSStringFromSelector(@selector(URL))];
    }
}

- (NSString *)mount_point
{
    return [self getValueForKey:NSStringFromSelector(@selector(mount_point))];
}

- (void)setMount_point:(NSString *)mount_point
{
    [self updateValue:mount_point forKey:NSStringFromSelector(@selector(mount_point))];
}

- (NSString *)port
{
    return [self getValueForKey:NSStringFromSelector(@selector(port))];
}

- (void)setPort:(NSString *)port
{
    [self updateValue:port forKey:NSStringFromSelector(@selector(port))];
}

- (NSString *)share_name
{
    return [self getValueForKey:NSStringFromSelector(@selector(share_name))];
}

- (void)setShare_name:(NSString *)share_name
{
    [self updateValue:share_name forKey:NSStringFromSelector(@selector(share_name))];
}

- (NSString *)username
{
    return [self getValueForKey:NSStringFromSelector(@selector(username))];
}

- (void)setUsername:(NSString *)username
{
    [self updateValue:username forKey:NSStringFromSelector(@selector(username))];
}

- (NSString *)password
{
    return [self getValueForKey:NSStringFromSelector(@selector(password))];
}

- (void)setPassword:(NSString *)password
{
    [self updateValue:password forKey:NSStringFromSelector(@selector(password))];
}

- (NSString *)domain
{
    return [self getValueForKey:NSStringFromSelector(@selector(domain))];
}

- (void)setDomain:(NSString *)domain
{
    [self updateValue:domain forKey:NSStringFromSelector(@selector(domain))];
}

- (NSString *)typeString
{
    return [self getValueForKey:NSStringFromSelector(@selector(type))];
}

- (void)setTypeString:(NSString *)typeString
{
    [self updateValue:typeString forKey:NSStringFromSelector(@selector(type))];
}

#pragma mark - Add / Remove
- (BOOL)save
{
    if (![self hasRequiredKeys]) {
        return NO;
    }

    LGJSSImporterDefaults *defaults = [[LGJSSImporterDefaults alloc] init];
    NSMutableOrderedSet *repos = [[NSMutableOrderedSet alloc] initWithArray:defaults.JSSRepos];
    NSUInteger index = [self findMatchInExisting:repos];

    if (index == NSNotFound) {
        [repos addObject:self.representation];
    } else {
        [repos replaceObjectAtIndex:index withObject:self.representation];
    }
    defaults.JSSRepos = repos.array;
    return YES;
}

- (BOOL)remove
{
    LGJSSImporterDefaults *defaults = [[LGJSSImporterDefaults alloc] init];
    NSMutableOrderedSet *repos = [[NSMutableOrderedSet alloc] initWithArray:defaults.JSSRepos];

    NSUInteger index = [self findMatchInExisting:repos];

    if (index != NSNotFound) {
        [repos removeObjectAtIndex:index];
        defaults.JSSRepos = repos.array;
    }
    return YES;
}

- (NSInteger)findMatchInExisting:(id)repos
{
    NSDictionary *representation = self.representation.copy;
    NSArray *exclusiveUnique = keyInfoDict()[@(self.type)][kExclusiveUnique];
    NSUInteger index = [repos indexOfObjectPassingTest:
                                  ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                                      if (!dict[kLGJSSDistPointTypeKey] ||
                                          [dict[kLGJSSDistPointTypeKey] isEqualToString:representation[kLGJSSDistPointTypeKey]]) {
                                          for (NSString *key in exclusiveUnique) {
                                              if ([representation[key] isEqualToString:dict[key]]) {
                                                  *stop = YES;
                                                  return YES;
                                              }
                                          }
                                      }
                                      return NO;
                                  }];
    return index;
}

+ (NSArray *)distributionPoints
{
    NSArray *array = [[[LGJSSImporterDefaults alloc] init] JSSRepos];
    if (!array.count) {
        return nil;
    }

    NSMutableArray *repos = [[NSMutableArray alloc] initWithCapacity:array.count];
    [array enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *_Nonnull stop) {
        id distPoint = [[[self class] alloc] initWithDictionary:obj];
        if (distPoint) {
            [repos addObject:distPoint];
        }
    }];
    return repos.copy;
}

@end
