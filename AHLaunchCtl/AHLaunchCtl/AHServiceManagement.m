//
//  AHServiceManagement.m
//  AHLaunchCtl
//
//  Created by Eldon on 2/16/14.
//  Copyright (c) 2014 Eldon Ahrold. All rights reserved.
//

#import "AHServiceManagement.h"
#import "AHLaunchJob.h"
#import <ServiceManagement/ServiceManagement.h>

const CFStringRef SMDomain(AHLaunchDomain domain)
{
    if (domain > kAHGlobalLaunchAgent) {
        return kSMDomainSystemLaunchd;
    } else {
        return kSMDomainUserLaunchd;
    }
}

NSDictionary* AHJobCopyDictionary(AHLaunchDomain domain, NSString* label)
{
    NSDictionary* dict;
    if (label && domain != 0) {
        dict = CFBridgingRelease(
            SMJobCopyDictionary(SMDomain(domain), (__bridge CFStringRef)(label)));
        return dict;
    } else {
        return nil;
    }
}

BOOL AHJobSubmit(AHLaunchDomain domain, NSDictionary* dictionary,
                 AuthorizationRef authRef, NSError* __autoreleasing* error)
{
    CFErrorRef cfError;
    if (domain == 0)
        return NO;
    cfError = NULL;

    BOOL rc = SMJobSubmit(SMDomain(domain), (__bridge CFDictionaryRef)dictionary,
                          authRef, &cfError);

    if (!rc) {
        NSError* err = CFBridgingRelease(cfError);
        if (error)
            *error = err;
    }

    return rc;
}

BOOL AHJobRemove(AHLaunchDomain domain, NSString* label,
                 AuthorizationRef authRef, NSError* __autoreleasing* error)
{
    CFErrorRef cfError;
    if (domain == 0)
        return NO;
    cfError = NULL;

    BOOL rc = SMJobRemove(SMDomain(domain), (__bridge CFStringRef)(label),
                          authRef, YES, &cfError);

    if (!rc) {
        NSError* err = CFBridgingRelease(cfError);
        if (error)
            *error = err;
    }
    return rc;
}

BOOL AHJobBless(AHLaunchDomain domain, NSString* label,
                AuthorizationRef authRef, NSError* __autoreleasing* error)
{
    if (domain == 0)
        return NO;

    CFErrorRef cfError = NULL;
    BOOL rc = NO;

    rc = SMJobBless(kSMDomainSystemLaunchd, (__bridge CFStringRef)(label),
                    authRef, &cfError);
    if (!rc) {
        NSError* err = CFBridgingRelease(cfError);
        if (error)
            *error = err;
    }
    return rc;
}

NSArray* AHCopyAllJobDictionaries(AHLaunchDomain domain)
{
    return CFBridgingRelease(SMCopyAllJobDictionaries(SMDomain(domain)));
}