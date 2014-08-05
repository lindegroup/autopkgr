//
//  AHKeychain.m
//  AHKeychain
//
//  Created by Eldon Ahrold on 5/7/14.
//  https://github.com/eahrold/ahkeychain/
//
// This class is a derivative of SSKeychain https://github.com/soffes/sskeychain/
// And released under the same license.
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

#import "AHKeychain.h"

NSString *const kAHKeychainItemErrorDomain = @"com.eeaapps.ahkeychain";
NSString *const kAHKeychainSystemKeychain  = @"com.eeaapps.ahkeychain.system";
NSString *const kAHKeychainLoginKeychain   = @"com.eeaapps.ahkeychain.login";

typedef NS_ENUM(int, AHKeychainErrorCode) {
    kAHKeychainErrKeychainAlreadyExists = -1,
    kAHKeychainErrMissingKey = 1000,
    kAHKeychainErrNoPasswordGiven,
    kAHKeychainErrCouldNotCreateAccess,
    kAHKeychainErrCannotDeleteSystemKeychain = 2000,
    kAHKeychainErrCannotDeleteDefaultLoginKeychain,
} ;

@interface AHKeychain ()
@property  (nonatomic,strong) id keychainObject;
@end


@implementation AHKeychain
@synthesize name = _name;

#pragma mark - Modifying Keychain

#pragma mark -- Initializers --
-(instancetype)initWithKeychain:(NSString*)name{
    self = [super init];
    if(self){
        self.name = name;
    }
    return self;
}

-(instancetype)initCreatingNewKeychainAtPath:(NSString *)path
                                      domain:(AHKeychainDomain)domain
                                    password:(NSString *)password
{
    SecKeychainRef keychain;

    self = [super init];
    _keychainStatus = errSecSuccess;
    self.keychainDomain = kAHKeychainDomainUser;
    self.name = path;
    
    if(self){
        if([[NSFileManager defaultManager]fileExistsAtPath:path isDirectory:nil]){
            _keychainStatus = kAHKeychainErrKeychainAlreadyExists;
            OSStatus status;
            status = SecKeychainOpen(_name.UTF8String, &keychain);
            if(status == errSecSuccess)
                _keychainObject = CFBridgingRelease(keychain);
            else
                _keychainStatus = status;
        }else{
            
            _keychainStatus = SecKeychainCreate(path.UTF8String,
                                                password ? (UInt32)password.length:0,
                                                password ? password.UTF8String: NULL,
                                                password ? FALSE:TRUE,
                                                NULL,
                                                &keychain);
            
            if(_keychainStatus == errSecSuccess){
                // register the newly created keychain with the particular
                // search domin where it was created
                _keychainObject = CFBridgingRelease(keychain);
                CFArrayRef cfArray;
                SecKeychainCopyDomainSearchList(_keychainDomain, &cfArray);
                NSMutableArray *array = CFBridgingRelease(cfArray);
                [array addObject:_keychainObject];
                SecKeychainSetDomainSearchList(_keychainDomain, (__bridge CFArrayRef)(array));
            }
        }
    }
    return self;
}

-(instancetype)initCreatingNewKeychainAtPath:(NSString *)path password:(NSString *)password{
    NSPredicate *systemPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] %@",@"/Library/Keychains/"];

    NSPredicate *userPredicate = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[cd] %@",NSHomeDirectory()];
    
    AHKeychainDomain domain = kAHKeychainDomainDynamic;
    if([systemPredicate evaluateWithObject:path]){
        domain = kAHKeychainDomainSystem;
    }
    else if ([userPredicate evaluateWithObject:path]){
        domain = kAHKeychainDomainUser;
    }
    
    return [self initCreatingNewKeychainAtPath:path domain:domain password:password];
}

-(instancetype)initCreatingNewKeychainAtPath:(NSString *)path{
    return [ self initCreatingNewKeychainAtPath:path password:nil];
}

-(instancetype)initCreatingNewKeychain:(NSString *)name password:(NSString *)password{
    NSString *path = [NSString stringWithFormat:@"%@/Library/Keychains/%@.keychain",NSHomeDirectory(),name];
    return [ self initCreatingNewKeychainAtPath:path password:password];
}

-(instancetype)initCreatingNewKeychain:(NSString *)name{
     return [self initCreatingNewKeychain:name password:nil];
}

#pragma mark -- Modifiers --
-(BOOL)changeKeychainPassword:(NSString *)oldpass
                           to:(NSString *)newpass
                        error:(NSError *__autoreleasing *)error{
    /** Much of this was extracted from the keychain_set_settings.c
     http://www.opensource.apple.com/source/SecurityTool/SecurityTool-55115/
     */
    
    _keychainStatus = errSecSuccess;
    
    if (!oldpass || !newpass || !_name) {
        return [[self class]errorWithCode:kAHKeychainErrMissingKey error:error];
    }
    // SecKeychainChangePassword is from Apple's Private reseve <Security/SecKeychainPriv.h>
    // so we'll silence the warning here.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-function-declaration"
    (void)SecKeychainLock((__bridge SecKeychainRef)(_keychainObject));
    
    _keychainStatus = SecKeychainChangePassword((__bridge SecKeychainRef)self.keychainObject, (UInt32)oldpass.length, oldpass.UTF8String, (UInt32)newpass.length, newpass.UTF8String);
#pragma clang diagnostic pop
    return [[self class] errorWithCode:_keychainStatus error:error];
}


-(BOOL)deleteKeychain:(NSError *__autoreleasing *)error{
    _keychainStatus = errSecSuccess;
    if([self.name isEqualToString:self.defaultLoginKeychain]){
        _keychainStatus = kAHKeychainErrCannotDeleteDefaultLoginKeychain;
    }else if ([self.name isEqualToString:self.systemKeychain]){
        _keychainStatus = kAHKeychainErrCannotDeleteSystemKeychain;
    }
    
    if(self.keychainObject && (_keychainStatus == errSecSuccess)){
        _keychainStatus = SecKeychainDelete((__bridge SecKeychainRef)(self.keychainObject));
    }
    return [[self class]errorWithCode:_keychainStatus error:error];
}



#pragma mark - Modifying Keychain Items
-(BOOL)saveItem:(AHKeychainItem *)item error:(NSError *__autoreleasing *)error
{
    _keychainStatus = kAHKeychainErrMissingKey;
    if (!item.service || !item.account || !item.passwordData) {
		return [[self class]errorWithCode:_keychainStatus error:error];
	}
    
    NSMutableDictionary *query = nil;
    if(!(query = [self query:item error:error]))
        return NO;
    
    if([self itemExistsWithQuery:query error:error]){
        NSMutableDictionary *updateAttrs = [NSMutableDictionary new];
		[updateAttrs setObject:item.passwordData forKey:(__bridge id)kSecValueData];
		if(item.label){
			[updateAttrs setObject:item.label forKey:(__bridge id)kSecAttrLabel];
		}
		if(query[(__bridge id)(kSecAttrSynchronizable)]){
			[updateAttrs setObject:query[(__bridge id)(kSecAttrSynchronizable)]
                            forKey:(__bridge id)(kSecAttrSynchronizable)];
		}
		[query removeObjectForKey:(__bridge id)(kSecAttrSynchronizable)];
        _keychainStatus = SecItemUpdate((__bridge CFDictionaryRef)(query),
                               (__bridge CFDictionaryRef)updateAttrs);
        
        return [[self class]errorWithCode:_keychainStatus error:error];
    }
    

    
    [query setObject:item.passwordData forKey:(__bridge id)kSecValueData];
    if (item.label) {
        [query setObject:item.label forKey:(__bridge id)kSecAttrLabel];
    }
    
    
    if(item.trustedApplications.count > 0){
        [self createAccessForQuery:query item:item error:error];
    }
    
    _keychainStatus = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    return [[self class]errorWithCode:_keychainStatus error:error];
}

-(BOOL)getItem:(AHKeychainItem *)item error:(NSError *__autoreleasing *)error{
    _keychainStatus = errSecSuccess;
    CFTypeRef results;
    
    NSMutableDictionary *query = nil;
    if(!(query = [self query:item error:error]))
        return NO;
    
    [query setObject:@YES forKey:(__bridge id)kSecReturnData];
    _keychainStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &results);
    
	if (_keychainStatus != errSecSuccess) {
		return [[self class]errorWithCode:_keychainStatus error:error];
	}
    
    item.passwordData = (__bridge_transfer NSData *)results;
    return YES;
}

-(BOOL)deleteItem:(AHKeychainItem *)item error:(NSError *__autoreleasing *)error{
    _keychainStatus = errSecSuccess;
    if (!item.service || !item.account) {
        _keychainStatus = kAHKeychainErrMissingKey;
        return [[self class] errorWithCode:_keychainStatus error:error];
	}
    
    NSMutableDictionary *query = nil;
    if(!(query = [self query:item error:error]))
       return NO;
    
    CFTypeRef result = NULL;
    [query setObject:@YES forKey:(__bridge id)kSecReturnRef];
    _keychainStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (_keychainStatus == errSecSuccess) {
        _keychainStatus = SecKeychainItemDelete((SecKeychainItemRef)result);
        CFRelease(result);
    }
    
    return [[self class]errorWithCode:_keychainStatus error:error];
}

-(BOOL)findItem:(AHKeychainItem *)item error:(NSError *__autoreleasing *)error{
    NSMutableDictionary *query = nil;
    if(!(query = [self query:item error:error]))
        return NO;

    return [self itemExistsWithQuery:query error:error];
}

-(BOOL)itemExistsWithQuery:(NSDictionary*)query error:(NSError*__autoreleasing*)error{
    _keychainStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    return [[self class]errorWithCode:_keychainStatus error:error];
}

-(NSArray *)findAllItems:(NSError *__autoreleasing *)error{
    NSArray *array;
    return array;
}


#pragma mark - Accessors
#pragma  mark -- Getters --

-(id)keychainObject{
    /**  the basis of this was inspired by keychain_utilities.c
     *  http://www.opensource.apple.com/source/SecurityTool/SecurityTool-55115/
     */
    if(_keychainObject){
        return _keychainObject;
    }
    
    _keychainStatus = errSecInvalidKeychain;
    
    SecKeychainRef keychain = NULL;
    NSFileManager *fm = [NSFileManager new];
    
    if([fm fileExistsAtPath:_name]){
        _keychainStatus = SecKeychainOpen(_name.UTF8String, &keychain);
        if(_keychainStatus == errSecSuccess)
            return CFBridgingRelease(keychain);
    }
    else{
        CFArrayRef kcArray = NULL;
        _keychainStatus = SecKeychainCopyDomainSearchList(kSecPreferencesDomainDynamic, &kcArray);
        if (_keychainStatus == errSecSuccess){
            // set the status here so if a match is not found in the for loop
            // the status code will be appropriate
            _keychainStatus = errSecInvalidKeychain;
            
            // convert it over to ARC for fast enumeration
            NSArray *keychainsList = CFBridgingRelease(kcArray);
            
            char pathName[MAXPATHLEN];
            UInt32 pathLength = sizeof(pathName);
            for ( id keychain in keychainsList){
                bzero(pathName, pathLength);
                OSStatus err = SecKeychainGetPath((__bridge SecKeychainRef)(keychain), &pathLength, pathName);
                if (err == errSecSuccess){
                    NSString* foundKeychainName = [[[NSString stringWithUTF8String:pathName]
                                                    lastPathComponent] stringByDeletingPathExtension];
                    if ([foundKeychainName isEqualToString:_name]){
                        _keychainStatus = errSecSuccess;
                        return keychain;
                    }
                }
            }
        }
    }
    return nil;
}

-(NSString *)name{
    if(_keychainObject){
        _keychainStatus = errSecSuccess;
        char pathName[MAXPATHLEN];
        UInt32 pathLength = sizeof(pathName);
        bzero(pathName, pathLength);
        _keychainStatus = SecKeychainGetPath((__bridge SecKeychainRef)(_keychainObject),
                                    &pathLength, pathName);
        if(_keychainStatus == errSecSuccess){
            return [NSString stringWithUTF8String:pathName];
        }
    }
    return _name;
}

-(NSString *)statusDescription{
    return [[self class] errorMessage:self.keychainStatus];
}

-(NSString *)defaultLoginKeychain{
    return [NSString stringWithFormat:@"%@/Library/Keychains/login.keychain",NSHomeDirectory()];
}

-(NSString *)systemKeychain{
    return @"/Library/Keychains/System.keychain";
}


#pragma  mark -- Setters --
-(void)setKeychainDomain:(AHKeychainDomain)keychainDomain{
    _keychainDomain = keychainDomain;
    if( !_keychainObject && !_name ){
        switch (keychainDomain) {
            case kAHKeychainDomainSystem:
                self.name = kAHKeychainSystemKeychain;
                break;
            default:
                self.name = kAHKeychainLoginKeychain;
                break;
        }
    }
}

-(void)setName:(NSString *)name{
    if([name isEqualToString:kAHKeychainLoginKeychain]){
        _name = self.defaultLoginKeychain;
    }
    else if([name isEqualToString:kAHKeychainSystemKeychain]){
        _name = self.systemKeychain;
    }
    else{
        _name = name;
    }
}

#pragma mark - Private
-(NSMutableDictionary*)query:(AHKeychainItem*)item error:(NSError*__autoreleasing*)error{
    NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:5];
    [query setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [query setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    if (item.service) {
        [query setObject:item.service forKey:(__bridge id)kSecAttrService];
    }
    
    if (item.account) {
        [query setObject:item.account forKey:(__bridge id)kSecAttrAccount];
    }
    
    _keychainObject = self.keychainObject;
    if (_keychainObject){
        [query setObject:_keychainObject forKey:(__bridge id)kSecUseKeychain];
    }

#if AHKEYCHAIN_SYNCHRONIZATION_AVAILABLE
	if ([[self class] isSynchronizationAvailable]) {
		id value;
        
		switch (item.synchronizationMode) {
			case AHKeychainQuerySynchronizationModeNo: {
                value = @NO;
                break;
			}
			case AHKeychainQuerySynchronizationModeYes: {
                value = @YES;
                break;
			}
			case AHKeychainQuerySynchronizationModeAny: {
                value = (__bridge id)(kSecAttrSynchronizableAny);
                break;
			}
		}
        
		[query setObject:value forKey:(__bridge id)(kSecAttrSynchronizable)];
	}
#endif

    return query;
}

-(BOOL)createAccessForQuery:(NSMutableDictionary*)query item:(AHKeychainItem*)item error:(NSError*__autoreleasing*)error;
{
    SecAccessRef access=nil;
    NSMutableArray *trustedApplications=[[NSMutableArray alloc]init];
    
    // Make an exception list of trusted applications; that is,
    // applications that are allowed to access the item without
    // requiring user confirmation:
    SecTrustedApplicationRef secTrustSelf;
    
    //Create trusted application references for this app//
    _keychainStatus = SecTrustedApplicationCreateFromPath(NULL, &secTrustSelf);
    
    // If we can't add ourself something's gon really wrong... abort.
    if (_keychainStatus != errSecSuccess) {
        return [[self class] errorWithCode:_keychainStatus error:error];
    }
    [trustedApplications addObject:(__bridge_transfer id)secTrustSelf];
    
    // calling SecTrustedApplicationCreateFromPath with NULL as the path
    // adds the caller, so we'll get that so we can skip it if it's
    // in the self.trustedApplications array.
    NSString *caller = [[NSProcessInfo processInfo] arguments][0];
    NSFileManager *fm = [NSFileManager new];
    
    //Create trusted application references any other specified apps//
    for(NSString *app in item.trustedApplications){
        if([fm fileExistsAtPath:app] && ![app isEqualToString:caller]){
            SecTrustedApplicationRef secTrustedApp = NULL;
            _keychainStatus = SecTrustedApplicationCreateFromPath(app.UTF8String,
                                                         &secTrustedApp);
            if (_keychainStatus == errSecSuccess) {
                [trustedApplications addObject:CFBridgingRelease(secTrustedApp)];
            }
        }
    }
    
    //Create an access object:
    _keychainStatus = SecAccessCreate((__bridge CFStringRef)item.service,
                             (__bridge CFArrayRef)trustedApplications,
                             &access);
    
    if(_keychainStatus == errSecSuccess){
        [query setObject:CFBridgingRelease(access) forKey:(__bridge id)kSecAttrAccess];
    }
    
    return [[self class] errorWithCode:_keychainStatus error:error];
}


#pragma mark - Class Methods
+(AHKeychain*)systemKeychain{
    AHKeychain *keychain = [[AHKeychain alloc]init];
    keychain.keychainDomain = kAHKeychainDomainSystem;
    return keychain;
}

+(AHKeychain*)loginKeychain{
    AHKeychain *keychain = [[AHKeychain alloc]init];
    keychain.keychainDomain = kAHKeychainDomainUser;
    return keychain;
}

+(AHKeychain*)keychainAtPath:(NSString*)path{
    AHKeychain *keychain = [[AHKeychain alloc]init];
    keychain.name = path;
    keychain.keychainDomain = kAHKeychainDomainDynamic;
    return keychain;
}


+(BOOL)setPassword:(NSString *)password
           service:(NSString *)service
           account:(NSString *)account
          keychain:(NSString *)keychain
       trustedApps:(NSArray  *)trustedApps
             error:(NSError  *__autoreleasing *)error
{
    AHKeychain *kc = [AHKeychain new];
    if(keychain)kc.name = keychain;
    AHKeychainItem *item = [AHKeychainItem new];
    item.account = account;
    item.service = service;
    item.password = password;
    item.trustedApplications = trustedApps;
    return [kc saveItem:item error:error];
}

+(BOOL)setPassword:(NSString *)password
           service:(NSString *)service
           account:(NSString *)account
          keychain:(NSString *)keycahin
             error:(NSError  *__autoreleasing *)error
{
    return [self setPassword:password service:service account:account keychain:keycahin trustedApps:nil error:error];
}


+(NSString*)getPasswordForService:(NSString *)service
                          account:(NSString *)account
                         keychain:(NSString *)keychain
                            error:(NSError  *__autoreleasing *)error
{
    AHKeychain *kc = [[AHKeychain alloc]init];
    if(keychain)kc.name = keychain;

    AHKeychainItem *item = [AHKeychainItem new];
    item.account = account;
    item.service = service;
    [kc getItem:item error:error];
    return item.password;
}

+(BOOL)removePasswordForService:(NSString *)service
                        account:(NSString *)account
                       keychain:(NSString *)keychain
                          error:(NSError  *__autoreleasing *)error{
    AHKeychain *kc = [AHKeychain new];
    if(keychain)kc.name = keychain;
    
    AHKeychainItem *item = [AHKeychainItem new];
    item.account = account;
    item.service = service;
    return [kc deleteItem:item error:error ];
}

+ (NSString*)errorMessage:(OSStatus)code{
    NSString *message = nil;
    switch (code){
        case kAHKeychainErrKeychainAlreadyExists:
            message = @"Cannot create keychain at that path, one already exists";
            break;
        case kAHKeychainErrMissingKey:
            message = @"Setting keychain password requires both account and service name";
            break;
        case kAHKeychainErrNoPasswordGiven:
            message = @"No password was supplied for chaingin the keychain password";
            break;
        case kAHKeychainErrCouldNotCreateAccess:
            message = @"Could Not create proper access for the keychain item";
            break;
        case kAHKeychainErrCannotDeleteSystemKeychain:
            message = @"The removal of the system keychain is not allowed";
            break;
        case kAHKeychainErrCannotDeleteDefaultLoginKeychain:
            message = @"The removal of the default login keychain is not allowed";
            break;
        default:
            message = (__bridge_transfer NSString *)SecCopyErrorMessageString(code, NULL);
            break;
    }
    return message;
}

#if AHKEYCHAIN_SYNCHRONIZATION_AVAILABLE
+ (BOOL)isSynchronizationAvailable {
	return floor(NSFoundationVersionNumber) > NSFoundationVersionNumber10_8_4;
}
#endif

+ (BOOL)errorWithCode:(OSStatus)code error:(NSError*__autoreleasing*)error{
    if (code == errSecSuccess){
        if(error)*error = nil;
        return YES;
    }
    NSString *message = [[self class]errorMessage:code];
    NSDictionary *userInfo = nil;
    if (message != nil) {
        userInfo = message ? @{ NSLocalizedDescriptionKey : message }:@{ NSLocalizedDescriptionKey : @"unknown error" };
    }
    if(error)*error = [NSError errorWithDomain:kAHKeychainItemErrorDomain
                                          code:code
                                      userInfo:userInfo];
    return NO;
}

@end
