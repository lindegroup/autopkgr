//
//  LGEncryptedKeychainHelper.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 9/23/16.
//  Copyright © 2016 The Linde Group, Inc. All rights reserved.
//

#import "LGEncryptedKeychainHelper.h"
#import "LGSharedConts.h"

#import <AHKeychain/AHKeychain.h>
#import <RNCryptor/RNDecryptor.h>
#import <RNCryptor/RNEncryptor.h>

#import <syslog.h>
#import <pwd.h>


// Parent directory for all of the keyFiles. Each AutoPkgr user has a unique file.
static NSString *const kLGEncryptedKeysParentDirectory = @"/var/db/.AutoPkgrKeys";

@implementation LGEncryptedKeychainHelper

+ (void)purge:(NSXPCConnection *)connection error:(NSError *__autoreleasing *)error
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF == .DS_Store"];

    NSArray *keyFiles = [[manager contentsOfDirectoryAtPath:kLGEncryptedKeysParentDirectory
                                                      error:nil]
                         filteredArrayUsingPredicate:predicate];

    if (keyFiles.count) {
        NSString *encryptedKeyFile = [NSString stringWithFormat:@"%@/UID_%d",
                                      kLGEncryptedKeysParentDirectory,
                                      connection.effectiveUserIdentifier];
        if (keyFiles.count == 1) {
            /* If the count is 1 there's only one user
             remove the whole directory & common encryption key */
            if ([manager fileExistsAtPath:encryptedKeyFile]) {
                if ([manager removeItemAtPath:kLGEncryptedKeysParentDirectory error:nil]) {
                    /* Remove keychain item. */
                    AHKeychainItem *item = [self commonDecryptionKeychainItem];
                    [[AHKeychain systemKeychain] deleteItem:item error:error];
                }
            }
        }
        else {
            /* More than one user encryptedKeyFile exists.
             Just remove the current user's */
            [manager removeItemAtPath:encryptedKeyFile error:error];
        }
    }
}

+ (NSString *)keychainPath:(struct passwd *)pw
{
    NSString *path =  [AUTOPKGR_KEYCHAIN_PATH stringByReplacingOccurrencesOfString:@"~" withString:[NSString stringWithUTF8String:pw->pw_dir]];

    return path;

}


+ (NSString *)getKeychainPassword:(NSXPCConnection *)connection error:(NSError *__autoreleasing *)error
{

    uid_t euid = connection.effectiveUserIdentifier;

    struct passwd *pw = getpwuid(connection.effectiveUserIdentifier);

    NSError *err = nil;

    // Password used to decrypt the keyFile. This password is stored in the System.keychain.
    NSString *encryptionPassword = nil;

    // Path to current user's keyFile. Encoded with AES256 using the encryption password.
    NSString *encryptedKeyFile = nil;

    // Data representing the keyFile. This data is encoded
    NSData *encryptedKeyFileData = nil;

    // The decoded raw data from the keyFile representing the password for the user's keychain.
    NSData *passwordData = nil;

    // The password for the user's keychain (in string form).
    NSString *password = nil;


    // Attributes used to set permissions on the keyFile and it's parent directory.
    NSDictionary *const attributes = [self encryptionKeyFileSystemAttributes];
    NSFileManager *manager = [NSFileManager defaultManager];

    encryptedKeyFile = [NSString stringWithFormat:@"%@/UID_%d", kLGEncryptedKeysParentDirectory, euid];

    /////////////////////////////////////////////////////////////////
    //  Get the encryption password from the System.keychain       //
    /////////////////////////////////////////////////////////////////
    AHKeychainItem *item = [self commonDecryptionKeychainItem];

    BOOL newEncryptionPassword = NO;

    AHKeychain *keychain = [AHKeychain systemKeychain];

    if ([keychain getItem:item error:&err]) {
        // We found the encryption password.
        encryptionPassword = item.password;
    }

    else if (err.code == errSecItemNotFound) {
        // The item was not found in the keychain. Create it now.

        // Reset the error so it doesn't inadvertently pass back the wrong message.
        err = nil;

        // Generate a new encryption password.
        encryptionPassword = [[NSProcessInfo processInfo] globallyUniqueString];
        item.password = encryptionPassword;

        if ([[AHKeychain systemKeychain] saveItem:item error:&err]) {
            // Success, a new common encryption was generated.
            newEncryptionPassword = YES;
        }
        else {
            if(error)*error = err;
            // If we can't create the keychain return now. There's nothing more to be done.
            return nil;
        }
    }
    else {
        if(error)*error = err;
        // some other error occurred when trying to find the item ???
        return nil;
    }


    // Check for an old version of the keychainKey.
    BOOL keyFileExists = [manager fileExistsAtPath:encryptedKeyFile];

    // Check to see if user's AutoPkgr keychain exists.
    BOOL usersKeychainExists = [AHKeychain keychainExistsAtPath:[self keychainPath:pw]];;

    // If the user's AutoPkgr keychain has been deleted, try to remove the keyFile and start fresh.
    BOOL check1 = !usersKeychainExists && keyFileExists;

    // If a new encryption key was generated, but an old keyFile exists.
    BOOL check2 = keyFileExists && newEncryptionPassword;

    // If either condition is true, remove the old keyFile.
    if (check1 || check2) {
        syslog(LOG_ALERT, "Removing unusable keyFile...");
        if (![manager removeItemAtPath:encryptedKeyFile error:nil]) {
            syslog(LOG_ALERT, "There was a problem removing the encrypted key file");
        }
    }

    //////////////////////////////////////////////////////////////////////
    //   Decrypt the keyFile in a root protected space                  //
    //////////////////////////////////////////////////////////////////////
    if (![manager fileExistsAtPath:encryptedKeyFile]) {
        // The keyFile does not exist, create one now.

        BOOL isDir;
        BOOL directoryExists = [manager fileExistsAtPath:kLGEncryptedKeysParentDirectory isDirectory:&isDir];

        if (!directoryExists) {
            if (![manager createDirectoryAtPath:kLGEncryptedKeysParentDirectory withIntermediateDirectories:NO attributes:attributes error:error]) {
                // If we can't create this directory something is wrong, return now.
                syslog(LOG_ALERT, "[ERROR] Could not create the parent directory for the encrypted key files.");
                return nil;
            }
        }

        else if (directoryExists && !isDir) {
            // The path exists but is not a directory, escape!.
            syslog(LOG_ALERT, "[ERROR] The %s exists, but it is not a directory, it needs to be repaired.", kLGEncryptedKeysParentDirectory.UTF8String);
            return nil;
        }

        // Generate some random data to use as the password for the user's keychain.
        passwordData = [RNCryptor randomDataOfLength:48];

        // Encrypt the random data into AES256.
        encryptedKeyFileData = [RNEncryptor encryptData:passwordData
                                           withSettings:kRNCryptorAES256Settings
                                               password:encryptionPassword
                                                  error:error];

        // Write the encrypted data to the keyFile.
        [encryptedKeyFileData writeToFile:encryptedKeyFile atomically:YES];
    }
    else {
        // The keyFile is there.

        // Read in the encrypted data of the keyFile.
        encryptedKeyFileData = [NSData dataWithContentsOfFile:encryptedKeyFile];

        // Decrypt the data.
        passwordData = [RNDecryptor decryptData:encryptedKeyFileData
                                   withSettings:kRNCryptorAES256Settings
                                       password:encryptionPassword
                                          error:error];
    }

    // Reset the attributes of the file to root only access.
    if (![manager setAttributes:attributes ofItemAtPath:encryptedKeyFile error:nil]) {
        syslog(LOG_ALERT, "[ERROR] A problem was encountered updating keyFile's permissions.");
    }

    if (passwordData) {
        // set the password as the data description.
        password = passwordData.description;
    }
    return password;
}


#pragma mark - Private
+ (NSDictionary *)encryptionKeyFileSystemAttributes
{
    return @{
             NSFilePosixPermissions : [NSNumber numberWithShort:0700], // Owner read-write, others no access.
             NSFileOwnerAccountID : @(0), // Root
             NSFileGroupOwnerAccountID : @(0), // Wheel
             };
}

+ (AHKeychainItem *)commonDecryptionKeychainItem
{
    AHKeychainItem *item = [[AHKeychainItem alloc] init];
    item.service = @"AutoPkgr Common Decryption";
    item.account = @"com.lindegroup.AutoPkgr.decryption.key";
    return item;
}

@end
