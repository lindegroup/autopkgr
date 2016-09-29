//
//  LGEncryptedKeychainHelper.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 9/23/16.
//  Copyright © 2016 The Linde Group, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LGEncryptedKeychainHelper : NSObject
+ (NSString *)getKeychainPassword:(NSXPCConnection *)connection error:(NSError **)error;
+ (void)purge:(NSXPCConnection *)connection error:(NSError *__autoreleasing *)error;
@end
