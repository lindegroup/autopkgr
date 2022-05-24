//
//  LGJamfDistributionPoint.m
//  AutoPkgr
//
//  Copyright 2022 The Linde Group.
//

#import "LGHTTPRequest.h"
#import "LGJamfDistributionPoint.h"
#import "LGJamfUploaderIntegration.h"
#import "LGLogger.h"
#import "LGServerCredentials.h"

#import "NSArray+mapped.h"

#pragma mark - Distribution Point Keys
NSString *const kLGJamfDistPointNameKey = @"name";
NSString *const kLGJamfDistPointURLKey = @"URL";
NSString *const kLGJamfDistPointSharePointKey = @"share_name";
NSString *const kLGJamfDistPointMountPointKey = @"mount_point";
NSString *const kLGJamfDistPointPortKey = @"port";
NSString *const kLGJamfDistPointUserNameKey = @"username";
NSString *const kLGJamfDistPointPasswordKey = @"password";
NSString *const kLGJamfDistPointWorkgroupDomainKey = @"domain";
NSString *const kLGJamfDistPointTypeKey = @"type";

#pragma mark - Key Dict
// Key used to indicate the array of required keys for a DP
const NSString *kJamfRequired = @"required";

// Key used to indicate the array of optional keys for a DP
const NSString *kJamfOptional = @"optional";

// Key used to indicate the array containing the keys used to
// determine whether the dp should be updated or inserted.
const NSString *kJamfExclusiveUnique = @"unique";

// Key used to indicate the type string for the key
const NSString *kJamfTypeString = @"typestr";

NSDictionary *keyJamfInfoDict()
{
    static dispatch_once_t onceToken;
    __strong static NSDictionary *dictionary = nil;
    dispatch_once(&onceToken, ^{
        // Required keys common on remote mountable types (AFP / SMB)
        NSArray *mountable = @[
            kLGJamfDistPointTypeKey,
            kLGJamfDistPointSharePointKey,
            kLGJamfDistPointURLKey,
            kLGJamfDistPointUserNameKey,
            kLGJamfDistPointPasswordKey,
        ];
        dictionary = @{
            // CDP
            @(kLGJamfTypeCDP) :
                @{ kJamfTypeString : @"CDP",
                   kJamfRequired : @[ kLGJamfDistPointTypeKey ],
                   kJamfOptional : @[],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointTypeKey ] },
            
            // Local
            @(kLGJamfTypeLocal) :
                @{ kJamfTypeString : @"Local",
                   kJamfRequired : @[ kLGJamfDistPointTypeKey,
                                  kLGJamfDistPointSharePointKey,
                                  kLGJamfDistPointMountPointKey ],
                   kJamfOptional : @[],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointTypeKey ] },

            // SMB
            @(kLGJamfTypeSMB) :
                @{ kJamfTypeString : @"SMB",
                   kJamfRequired : mountable,
                   kJamfOptional : @[ kLGJamfDistPointNameKey,
                                  kLGJamfDistPointPortKey,
                                  kLGJamfDistPointWorkgroupDomainKey ],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointURLKey ] },

            // AFP
            @(kLGJamfTypeAFP) :
                @{ kJamfTypeString : @"AFP",
                   kJamfRequired : mountable,
                   kJamfOptional : @[ kLGJamfDistPointNameKey,
                                  kLGJamfDistPointPortKey ],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointURLKey ] },

            // JDS
            @(kLGJamfTypeJDS) :
                @{ kJamfTypeString : @"JDS",
                   kJamfRequired : @[ kLGJamfDistPointTypeKey ],
                   kJamfOptional : @[],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointTypeKey ] },

            // From Jamf
            @(kLGJamfTypeFromJamf) :
                @{ kJamfRequired : @[ kLGJamfDistPointNameKey,
                                  kLGJamfDistPointPasswordKey ],
                   kJamfOptional : @[],
                   kJamfExclusiveUnique : @[ kLGJamfDistPointNameKey ] },
        };
    });
    return dictionary;
}

#pragma mark - LGJamfDistributionPoint
@implementation LGJamfDistributionPoint {
@private
    NSMutableDictionary *_dpDict;
}

+ (NSDictionary *)keyJamfInfoDict
{
    return keyJamfInfoDict();
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

- (instancetype)initWithType:(JamfDistributionPointType)type
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
- (void)setType:(JamfDistributionPointType)type
{
    NSString *typeString = keyJamfInfoDict()[@(type)][kJamfTypeString];
    if (typeString) {
        [_dpDict setObject:typeString forKey:kLGJamfDistPointTypeKey];
    }
}

- (JamfDistributionPointType)type
{
    NSString *type = [_dpDict[kLGJamfDistPointTypeKey] lowercaseString];
    NSDictionary *d = keyJamfInfoDict();
    for (NSNumber *k in d) {
        if ([[d[k][kJamfTypeString] lowercaseString] isEqualToString:type]) {
            return (JamfDistributionPointType)k.integerValue;
        }
    }
    assert(@"Correct type not determined.");
    return kLGJamfTypeFromJamf;
}

- (BOOL)validKeyForType:(NSString *)key
{
    // Type Keys is alwas valid
    if ([key isEqualToString:kLGJamfDistPointTypeKey]) {
        return YES;
    }

    NSNumber *type = @(self.type);
    NSDictionary *keys = keyJamfInfoDict()[type];
    return ([keys[kJamfRequired] containsObject:key] ||
            [keys[kJamfOptional] containsObject:key]);
}

- (BOOL)hasRequiredKeys
{
    NSDictionary *keys = keyJamfInfoDict()[@(self.type)];
    for (NSString *key in keys[kJamfRequired]) {
        if (!_dpDict[key]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)isEditable
{
    switch (self.type) {
    case kLGJamfTypeCDP:
    case kLGJamfTypeJDS:
        return NO;
    default:
        return YES;
    }
}
#pragma mark - Accesssors
#pragma mark-- Private --
- (void)updateValue:(NSString *)value forKey:(NSString *)key
{
    if ([self validKeyForType:key]) {
        if (value) {
            [_dpDict setObject:value forKey:key];
        }
        else {
            [_dpDict removeObjectForKey:key];
        }
    }
}

- (id)getValueForKey:(NSString *)key
{
    return [self validKeyForType:key] ? [_dpDict objectForKey:key] : nil;
}

#pragma mark-- Public --
- (NSString *)description
{
    NSString *description = nil;
    NSString *type = self.typeString;

    switch (self.type) {
    case kLGJamfTypeFromJamf: {
        description = quick_formatString(@"Name: %@", self.name);
        type = @"From Jamf";
        break;
    }
    case kLGJamfTypeAFP:
    case kLGJamfTypeSMB:
    case kLGJamfTypeLocal: {
        description = self.URL;
        break;
    }
    case kLGJamfTypeJDS:
        return @"JAMF Distribution Server";
    case kLGJamfTypeCDP:
        return @"Cloud Distribution Point";
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
    if (self.type == kLGJamfTypeLocal) {
        return self.share_name;
    }
    else {
        return [self getValueForKey:NSStringFromSelector(@selector(name))];
    }
}

- (void)setName:(NSString *)name
{
    if (self.type == kLGJamfTypeLocal) {
        self.share_name = name;
    }
    else {
        [self updateValue:name forKey:NSStringFromSelector(@selector(name))];
    }
}

- (NSString *)URL
{
    if (self.type == kLGJamfTypeLocal) {
        return self.mount_point;
    }
    else {
        return [self getValueForKey:NSStringFromSelector(@selector(URL))];
    }
}

- (void)setURL:(NSString *)URL
{
    if (self.type == kLGJamfTypeLocal) {
        self.mount_point = URL;
    }
    else {
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

    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
    NSMutableOrderedSet *repos = [[NSMutableOrderedSet alloc] initWithArray:defaults.JSSRepos];
    NSUInteger index = [self findMatchInExisting:repos];

    if (index == NSNotFound) {
        [repos addObject:self.representation];
    }
    else {
        [repos replaceObjectAtIndex:index withObject:self.representation];
    }
    defaults.JSSRepos = repos.array;
    return YES;
}

- (BOOL)remove
{
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];
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
    NSArray *exclusiveUnique = keyJamfInfoDict()[@(self.type)][kJamfExclusiveUnique];
    NSUInteger index = [repos indexOfObjectPassingTest:
                                  ^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                                      if (!dict[kLGJamfDistPointTypeKey] ||
                                          [dict[kLGJamfDistPointTypeKey] isEqualToString:representation[kLGJamfDistPointTypeKey]]) {
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

+ (NSArray *)enabledDistributionPoints
{
    NSArray *array = [[[LGJamfUploaderDefaults alloc] init] JSSRepos];
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

+ (void)getFromRemote:(void (^)(NSArray<LGJamfDistributionPoint *> *, NSError *))distPoints
{
    LGHTTPRequest *request = [[LGHTTPRequest alloc] init];
    LGJamfUploaderDefaults *defaults = [[LGJamfUploaderDefaults alloc] init];

    LGHTTPCredential *credentials = [[LGHTTPCredential alloc] initWithServer:defaults.JSSURL
                                                                        user:defaults.JSSAPIUsername
                                                                    password:defaults.JSSAPIPassword];

    credentials.sslTrustSetting = defaults.JSSVerifySSL ? kLGSSLTrustOSImplicitTrust : kLGSSLTrustUserConfirmedTrust;

    [request retrieveDistributionPoints:credentials
                                  reply:^(NSDictionary *dp, NSError *error) {
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          distPoints([self normalizeDistributionPoints:dp], error);
                                      });
                                  }];
}

#pragma mark - Normalize
+ (NSArray<LGJamfDistributionPoint *> *)normalizeDistributionPoints:(NSDictionary *)distributionPoints
{
    id distPoints;

    // If the object was parsed as an XML object the key we're looking for is
    // distribution_point. If the object is a JSON object the key is distribution_points
    if ((distPoints = distributionPoints[@"distribution_point"]) == nil && (distPoints = distributionPoints[@"distribution_points"]) == nil) {
        return nil;
    }

    NSArray *dictArray;
    // If there is just one ditribution point distPoint will be a dictionary entry
    // and we need to normalize it here by wrapping it in an array.
    if ([distPoints isKindOfClass:[NSDictionary class]]) {
        dictArray = @[ distPoints ];
    }
    // If there are more then one entries distPoint will be an array, so pass it along.
    else if ([distPoints isKindOfClass:[NSArray class]]) {
        dictArray = distPoints;
    }

    return [dictArray mapObjectsUsingBlock:^LGJamfDistributionPoint *(NSDictionary *obj, NSUInteger idx) {
        return [[LGJamfDistributionPoint alloc] initWithDictionary:obj];
    }];
}
@end
