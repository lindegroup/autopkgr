//
//  LGPasswords.m
//  AutoPkgr
//
//  Created by Eldon Ahrold on 2/14/15.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//

#import "LGPasswords.h"
#import "LGAutoPkgrHelperConnection.h"
#import "LGAutoPkgr.h"
#import "AHKeychain.h"

@implementation LGPasswords

+ (void)migrateKeychainIfNeeded:(void (^)(NSString *password))reply;
{
    NSError *error;

    NSString *account = [[LGDefaults standardUserDefaults] SMTPUsername];
    NSString *keychainPath = [@"~/Library/Keychains/AutoPkgr.keychain" stringByExpandingTildeInPath];
    
    NSFileManager *fm = [NSFileManager defaultManager];

    if ([fm fileExistsAtPath:keychainPath]){
        AHKeychain *keychain = [LGHostInfo appKeychain];

        if (account) {
            AHKeychainItem *item = [[AHKeychainItem alloc] init];
            item.account = account;
            item.service = kLGAutoPkgrPreferenceDomain;
            item.label = kLGApplicationName;

            if([keychain getItem:item error:&error]){
                [[self class] savePassword:item.password forAccount:account reply:^(NSError *error) {
                    if (error) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            [self resetPasswordForAccount:account reply:reply];
                        }];
                    };
                }];
            }
        }
        [keychain deleteKeychain:&error];
    }
}

+ (void)getPasswordForAccount:(NSString *)account reply:(void (^)(NSString *, NSError *))reply
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];

        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            reply(nil, error);
            NSLog(@"%@", error.localizedDescription);
        }] getPasswordForAccount:account
         reply:reply];
    }];
};

+ (void)savePassword:(NSString *)password forAccount:(NSString *)account reply:(void (^)(NSError *))reply
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        LGAutoPkgrHelperConnection *helper = [LGAutoPkgrHelperConnection new];
        [helper connectToHelper];

        [[helper.connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
            reply(error);
            NSLog(@"%@", error.localizedDescription);
        }] savePassword:password
         forAccount:account
         reply:reply];
    }];
}

#pragma mark - Private
+ (void)resetPasswordForAccount:(NSString *)account reply:(void (^)(NSString *password))reply
{
    NSString *messageText = @"Error migrating password";
    NSString *infoText = @"There was a problem migrating the password for %@, enter it here to update. You can also update it later in the preference window";

    NSAlert *alert = [NSAlert alertWithMessageText:messageText
                                     defaultButton:@"OK"
                                   alternateButton:@"Cancel"
                                       otherButton:nil
                         informativeTextWithFormat:infoText, account];

    NSSecureTextField *input = [[NSSecureTextField alloc] init];
    [input setFrame:NSMakeRect(0, 0, 300, 24)];
    [alert setAccessoryView:input];

    NSInteger button = [alert runModal];
    if (button == NSAlertDefaultReturn) {
        [input validateEditing];
        NSString *password = [input stringValue];
        if (!password || [password isEqualToString:@""]) {
            return [self resetPasswordForAccount:account reply:reply];
        } else {
            [[self class] savePassword:password forAccount:account reply:^(NSError *error) {
                reply(password);
            }];
        }
    }
}
@end
