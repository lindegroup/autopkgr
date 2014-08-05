//
//  AHKeychainItem.h
//  AHKeychain
//
//  Created by Eldon Ahrold on 5/7/14.
//  https://github.com/eahrold/ahkeychain/
//
// This class is a derivitave of SSKeychain https://github.com/soffes/sskeychain/
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

#import <Foundation/Foundation.h>

#if __MAC_10_9
// Keychain synchronization available at compile time
#define AHKEYCHAIN_SYNCHRONIZATION_AVAILABLE 1
#endif

#ifdef AHKEYCHAIN_SYNCHRONIZATION_AVAILABLE
typedef NS_ENUM(NSUInteger, AHKeychainQuerySynchronizationMode) {
	AHKeychainQuerySynchronizationModeAny,
	AHKeychainQuerySynchronizationModeNo,
	AHKeychainQuerySynchronizationModeYes
};
#endif

@interface AHKeychainItem : NSObject

/**
 *  service name of keychain item
 */
@property (copy,nonatomic) NSString *service;

/**
 *  lable of keychain item
 */
@property (copy,nonatomic) NSString *label;

/**
 *  account name of keychain item
 */
@property (copy,nonatomic) NSString *account;

#if AHKEYCHAIN_SYNCHRONIZATION_AVAILABLE
/** kSecAttrSynchronizable */
@property (nonatomic) AHKeychainQuerySynchronizationMode synchronizationMode;
#endif
/**
 *   Root storage for password information
 */
@property (nonatomic, copy) NSData *passwordData;

/**
 This property automatically transitions between an object and the value of
 `passwordData` using NSKeyedArchiver and NSKeyedUnarchiver.
 */
@property (nonatomic, copy) id<NSCoding> passwordObject;

/**
 *  password for keychain item
 */
@property (copy,nonatomic) NSString *password;

/**
 *  Array of paths to applications that should have permission to the keychain
 */
@property (copy,nonatomic) NSArray  *trustedApplications;

@end
