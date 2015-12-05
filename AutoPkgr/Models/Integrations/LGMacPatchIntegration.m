//
//  LGMacPatchIntegration.m
//  AutoPkgr
//
//  Copyright 2015 The Linde Group, Inc.
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

#import "LGMacPatchIntegration.h"

@implementation LGMacPatchIntegration
+ (NSString *)name {
    return @"MacPatchImporter";
}

+ (NSString *)credits {
    return @"LLNL Mac Development\nGNU GENERAL PUBLIC LICENSE Version 2";
}

+ (NSArray *)components {
    return nil;
}

+ (NSString *)defaultRepository {
    return @"https://github.com/SMSG-MAC-DEV/MacPatch-AutoPKG.git";
}

+(NSURL *)homePage
{
    return [NSURL URLWithString: @"https://github.com/SMSG-MAC-DEV/MacPatch-AutoPKG"];
}

+ (BOOL)isUninstallable {
    return YES;
}

+ (NSString *)summaryResultsKey {
    return @"macpatch_importer_summary_result";
}

- (void)customUninstallActions:(void (^)(NSError *))reply {
    LGMacPatchDefaults *defaults = [LGMacPatchDefaults new];
    defaults.MP_PASSWORD = nil;
    defaults.MP_URL = nil;
    defaults.MP_USER = nil;
    defaults.MP_SSL_VERIFY = YES;

    // Don't forget to reply...
    reply(nil);
}

@end


@implementation LGMacPatchDefaults
// URL
- (NSString *)MP_URL {
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(MP_URL))];
}

-(void)setMP_URL:(NSString *)MP_URL {
    [self setAutoPkgDomainObject:MP_URL forKey:NSStringFromSelector(@selector(MP_URL))];
}

// USER
-(NSString *)MP_USER{
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(MP_USER))];

}

-(void)setMP_USER:(NSString *)MP_USER {
    [self setAutoPkgDomainObject:MP_USER forKey:NSStringFromSelector(@selector(MP_USER))];
}

// PASSWORD
- (NSString *)MP_PASSWORD {
    return [self autoPkgDomainObject:NSStringFromSelector(@selector(MP_PASSWORD))];

}

- (void)setMP_PASSWORD:(NSString *)MP_PASSWORD {
    [self setAutoPkgDomainObject:MP_PASSWORD forKey:NSStringFromSelector(@selector(MP_PASSWORD))];

}

// SSL_VERIFY
- (BOOL)MP_SSL_VERIFY {
    return [[self autoPkgDomainObject:NSStringFromSelector(@selector(MP_SSL_VERIFY))] boolValue];

}

- (void)setMP_SSL_VERIFY:(BOOL)MP_SSL_VERIFY {
    [self setAutoPkgDomainObject:@(MP_SSL_VERIFY) forKey:NSStringFromSelector(@selector(MP_SSL_VERIFY))];
}

@end