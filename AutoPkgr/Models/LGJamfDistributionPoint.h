//
//  LGJamfDistributionPoint.h
//  AutoPkgr
//
//  Copyright 2022 The Linde Group.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, JamfDistributionPointType) {
    kLGJamfTypeFromJamf = 1 << 0,
    kLGJamfTypeAFP = 1 << 1,
    kLGJamfTypeSMB = 1 << 2,
    kLGJamfTypeJDS = 1 << 3,
    kLGJamfTypeCDP = 1 << 4,
    kLGJamfTypeLocal = 1 << 5
};

extern NSString *const kLGJamfDistPointNameKey;
extern NSString *const kLGJamfDistPointURLKey;
extern NSString *const kLGJamfDistPointSharePointKey;
extern NSString *const kLGJamfDistPointMountPointKey;
extern NSString *const kLGJamfDistPointPortKey;
extern NSString *const kLGJamfDistPointUserNameKey;
extern NSString *const kLGJamfDistPointPasswordKey;
extern NSString *const kLGJamfDistPointWorkgroupDomainKey;
extern NSString *const kLGJamfDistPointTypeKey;

// Corresponding type string in keyJamfInfoDict().
extern const NSString *kJamfTypeString;
// Key used to indicate the array of required keys for a DP.
extern const NSString *kJamfRequired;
// Key used to indicate the array of optional keys for a DP.
extern const NSString *kJamfOptional;

@interface LGJamfDistributionPoint : NSObject
// Dictionary to query for type string.
// Corresponding values can be looked up using an NSNumber representation of JamfDistributionPointType as the key.
+ (NSDictionary *)keyJamfInfoDict;

+ (NSArray<LGJamfDistributionPoint *> *)enabledDistributionPoints;

+ (void)getFromRemote:(void (^)(NSArray<LGJamfDistributionPoint *> *distPoints, NSError *error))distPoints;

// The Dictionary representation of the Distribution Point object, suitable for writing to defaults.
@property (copy, readonly) NSDictionary *representation;
@property (copy) NSString *name;
@property (copy) NSString *URL;
@property (copy) NSString *mount_point;
@property (copy) NSString *port;
@property (copy) NSString *share_name;
@property (copy) NSString *username;
@property (copy) NSString *password;
@property (copy) NSString *domain;
@property (copy) NSString *typeString;
@property JamfDistributionPointType type;

- (BOOL)isEditable;

// Initialize a distribution point using a dictionary.
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (instancetype)initWithType:(JamfDistributionPointType)type;
- (instancetype)initWithTypeString:(NSString *)typeString;

// Save or modify an existing distribution point to defaults.
- (BOOL)save;

// Remove a distribution point.
- (BOOL)remove;

@end
