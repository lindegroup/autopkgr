//
//  LGJSSDistributionPoint.h
//  AutoPkgr
//
//  Created by Eldon on 11/9/15.
//  Copyright © 2015 The Linde Group, Inc. All rights reserved.
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

// Cooresponding type string in keyInfoDict()
extern const NSString *kTypeString;

@interface LGJSSDistributionPoint : NSObject
// Dictionary to query for type string
// Cooresponding values can be looked up
// using an NSNumber representation of JSSDistributionPointType
// as the key.
+ (NSDictionary *)keyInfoDict;

+ (NSArray<LGJSSDistributionPoint *> *)enabledDistributionPoints;

// The Dictionary representation of the Distribution Point object, sutiable for writing to defaults.
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

// Initialize a distribution point using a dictionary
- (instancetype)initWithDictionary:(NSDictionary *)dict;
- (instancetype)initWithType:(JSSDistributionPointType)type;
- (instancetype)initWithTypeString:(NSString *)typeString;

// Save or modifying and existing distribution point to defaults
- (BOOL)save;

// Remove a distribution point.
- (BOOL)remove;

@end
