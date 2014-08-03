//  AHAuthorizer.m
//  Copyright (c) 2014 Eldon Ahrold ( https://github.com/eahrold/AHLaunchCtl )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AHAuthorizer.h"
OSStatus SetupAuthorization(AuthorizationRef* gAuthorization);

static NSString* kCommandKeyAuthRightName = @"authRightName";
static NSString* kCommandKeyAuthRightDefault = @"authRightDefault";
static NSString* kCommandKeyAuthRightDesc = @"authRightDescription";
static NSString* kAHAuthorizationAdd = @"com.eeaapps.launchctl.add";
static NSString* kAHAuthorizationRemove = @"com.eeaapps.launchctl.remove";
static NSString* kAHAuthorizationStart = @"com.eeaapps.launchctl.start";
static NSString* kAHAuthorizationStop = @"com.eeaapps.launchctl.stop";
static NSString* kAHAuthorizationRestart = @"com.eeaapps.launchctl.restart";
static NSString* kAHAuthorizationRemoveHelper =
    @"com.eeaapps.launchctl.removehelper";
static NSString* kAHAuthorizationSessionAuth =
    @"com.eeaapps.launchctl.authsession";
static NSString* kAHAuthorizationSystemDaemon =
    @"com.eeaapps.launchctl.blesshelper";
static NSString* kAHAuthorizationJobBless =
    @"com.eeaapps.launchctl.system.daemon.modify";

static NSString* kNSAuthorizationJobBless =
    @"com.apple.ServiceManagement.blesshelper";
static NSString* kNSAuthorizationSystemDaemon =
    @"com.apple.ServiceManagement.daemons.modify";

@implementation AHAuthorizer {
    NSInteger _authTime;
}
#pragma mark - Rights dictionary
+ (NSDictionary*)commandInfo
{
    static dispatch_once_t onceToken;
    static NSDictionary* commandInfo;
    dispatch_once(&onceToken, ^{
      commandInfo = @{
        NSStringFromSelector(@selector(authorizeSMJobBlessWithPrompt:)) : @{
          kCommandKeyAuthRightName : kAHAuthorizationJobBless,
          kCommandKeyAuthRightDefault : @kAuthorizationRuleAuthenticateAsAdmin,
          kCommandKeyAuthRightDesc :
              NSLocalizedString(@"Install the Helper Tool?",
                                @"prompt shown when user is required to "
                                @"authorize to install helper tool")
        },
      };
    });
    return commandInfo;
}
#pragma mark - Authorization Methods
+ (NSError*)checkAuthorization:(NSData*)authData
                       command:(SEL)command
// Check that the client denoted by authData is allowed to run the specified
// command.  authData is expected to be an NSData with an
// AuthorizationExternalForm embedded inside.
{
#pragma unused(authData)
    NSError* error;
    OSStatus err;
    OSStatus junk;
    AuthorizationRef authRef;
    assert(command != nil);

    authRef = NULL;

    // First check that authData looks reasonable.
    error = nil;
    if ((authData == nil) || ([authData length] != sizeof(AuthorizationExternalForm))) {
        error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                    code:paramErr
                                userInfo:nil];
    }

    // Create an authorization ref from that the external form data contained
    // within.

    if (error == nil) {
        err = AuthorizationCreateFromExternalForm([authData bytes], &authRef);

        // Authorize the right associated with the command.

        if (err == errAuthorizationSuccess) {
            AuthorizationItem oneRight = { NULL, 0, NULL, 0 };

            oneRight.name = [[self authorizationRightForCommand:command] UTF8String];
            assert(oneRight.name != NULL);

            AuthorizationRights rights = { 1, &oneRight };

            err = AuthorizationCopyRights(
                authRef, &rights, NULL,
                kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed,
                NULL);
        }
        if (err != errAuthorizationSuccess) {
            error = [NSError
                errorWithDomain:NSOSStatusErrorDomain
                           code:err
                       userInfo:@{
                           NSLocalizedDescriptionKey :
                               @"You are not authorized to perform this action."
                               }];
        }
    }

    if (authRef != NULL) {
        junk = AuthorizationFree(authRef, 0);
        assert(junk == errAuthorizationSuccess);
    }

    return error;
}

+ (NSData*)authorizeHelper
{
    OSStatus err;
    AuthorizationExternalForm extForm;
    AuthorizationRef authRef;
    NSData* authorization;

    err = AuthorizationCreate(NULL, NULL, 0, &authRef);
    if (err == errAuthorizationSuccess) {
        err = AuthorizationMakeExternalForm(authRef, &extForm);
    }
    if (err == errAuthorizationSuccess) {
        authorization =
            [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
    }
    assert(err == errAuthorizationSuccess);

    if (authRef) {
        [[self class] setupAuthorizationRights:authRef];
    }
    return authorization;
}

+ (NSString*)authorizationRightForCommand:(SEL)command
// See comment in header.
{
    return [self commandInfo][NSStringFromSelector(
        command)][kCommandKeyAuthRightName];
}

+ (void)enumerateRightsUsingBlock:(void (^)(NSString* authRightName,
                                            id authRightDefault,
                                            NSString* authRightDesc))block
// Calls the supplied block with information about each known authorization
// right..
{
    [self.commandInfo enumerateKeysAndObjectsUsingBlock:^(id key, id obj,
                                                          BOOL* stop) {
#pragma unused(key)
#pragma unused(stop)
      NSDictionary *commandDict;
      NSString *authRightName;
      id authRightDefault;
      NSString *authRightDesc;

      // If any of the following asserts fire it's likely that you've got a bug
      // in sCommandInfo.

      commandDict = (NSDictionary *)obj;
      assert([commandDict isKindOfClass:[NSDictionary class]]);

      authRightName = [commandDict objectForKey:kCommandKeyAuthRightName];
      assert([authRightName isKindOfClass:[NSString class]]);

      authRightDefault = [commandDict objectForKey:kCommandKeyAuthRightDefault];
      assert(authRightDefault != nil);

      authRightDesc = [commandDict objectForKey:kCommandKeyAuthRightDesc];
      assert([authRightDesc isKindOfClass:[NSString class]]);

      block(authRightName, authRightDefault, authRightDesc);
    }];
}

+ (void)setupAuthorizationRights:(AuthorizationRef)authRef
{
    assert(authRef != NULL);
    [self enumerateRightsUsingBlock:^(NSString* authRightName,
                                      id authRightDefault,
                                      NSString* authRightDesc) {
      OSStatus blockErr;

      blockErr = AuthorizationRightGet([authRightName UTF8String], NULL);
      if (blockErr == errAuthorizationDenied) {
        blockErr = AuthorizationRightSet(authRef, [authRightName UTF8String],
                                         (__bridge CFTypeRef)authRightDefault,
                                         (__bridge CFStringRef)authRightDesc,
                                         NULL, CFSTR("Common"));
        assert(blockErr == errAuthorizationSuccess);
      } else {
      }
    }];
}

+ (AuthorizationFlags)defaultFlags
{
    static dispatch_once_t onceToken;
    static AuthorizationFlags authFlags;
    dispatch_once(&onceToken, ^{
      authFlags =
          kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
          kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    });
    return authFlags;
}

+ (AuthorizationRef)authorizeSystemDaemonWithPrompt:(NSString*)prompt
{
    AuthorizationItem authItem = {kNSAuthorizationSystemDaemon.UTF8String, 0,
                                  NULL, 0 };
    return [self authorizePrompt:prompt authItems:authItem];
}

+ (AuthorizationRef)authorizeSMJobBlessWithPrompt:(NSString*)prompt
{
    AuthorizationItem authItem = {kNSAuthorizationJobBless.UTF8String, 0, NULL,
                                  0 };
    return [self authorizePrompt:prompt authItems:authItem];
};

+ (AuthorizationRef)authorizePrompt:(NSString*)prompt
                          authItems:(AuthorizationItem)authItem
{
    AuthorizationRef authRef;

    AuthorizationRights authRights = { 1, &authItem };
    AuthorizationEnvironment environment = { 0, NULL };

    if (prompt) {
        AuthorizationItem envItem = { kAuthorizationEnvironmentPrompt, prompt.length,
                                      (void*)prompt.UTF8String, 0 };
        environment.count = 1;
        environment.items = &envItem;
    }

    OSStatus status = AuthorizationCreate(&authRights, &environment,
                                          [[self class] defaultFlags], &authRef);

    if (status != errAuthorizationSuccess) {
        return NULL;
    }
    return authRef;
}

+ (void)authoriztionFree:(AuthorizationRef)authRef
{
    if (authRef != NULL) {
        OSStatus junk = AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
        assert(junk == errAuthorizationSuccess);
    }
}



@end
