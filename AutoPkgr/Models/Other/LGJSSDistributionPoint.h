//
//  LGJSSDistributionPoint.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 11/9/15.
//  Copyright 2015-2016 The Linde Group, Inc.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, JSSDistributionPointType) {
    kLGJSSTypeFromJSS = 1 << 0,
    kLGJSSTypeAFP = 1 << 1,
    kLGJSSTypeSMB = 1 << 2,
    kLGJSSTypeJDS = 1 << 3,
    kLGJSSTypeCDP = 1 << 4,
    kLGJSSTypeLocal = 1 << 5
};

extern NSString *const kLGJSSDistPointNameKey;
extern NSString *const kLGJSSDistPointURLKey;
extern NSString *const kLGJSSDistPointSharePointKey;
extern NSString *const kLGJSSDistPointMountPointKey;
extern NSString *const kLGJSSDistPointPortKey;
extern NSString *const kLGJSSDistPointUserNameKey;
extern NSString *const kLGJSSDistPointPasswordKey;
extern NSString *const kLGJSSDistPointWorkgroupDomainKey;
extern NSString *const kLGJSSDistPointTypeKey;

// Corresponding type string in keyInfoDict().
extern const NSString *kTypeString;
// Key used to indicate the array of required keys for a DP.
extern const NSString *kRequired;
// Key used to indicate the array of optional keys for a DP.
extern const NSString *kOptional;

@interface LGJSSDistributionPoint : NSObject
// Dictionary to query for type string.
// Corresponding values can be looked up using an NSNumber representation of JSSDistributionPointType as the key.
+ (NSDictionary *)keyInfoDict;

+ (NSArray<LGJSSDistributionPoint *> *)enabledDistributionPoints;

+ (void)getFromRemote:(void (^)(NSArray<LGJSSDistributionPoint *> *distPoints, NSError *error))distPoints;

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
@property JSSDistributionPointType type;

- (BOOL)isEditable;

// Initialize a distribution point using a dictionary.
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (instancetype)initWithType:(JSSDistributionPointType)type;
- (instancetype)initWithTypeString:(NSString *)typeString;

// Save or modify an existing distribution point to defaults.
- (BOOL)save;

// Remove a distribution point.
- (BOOL)remove;

@end
