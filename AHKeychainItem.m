//
//  AHKeychainItem.m
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

#import "AHKeychainItem.h"

@implementation AHKeychainItem

#pragma mark - Public

-(NSString *)description{
    return [NSString stringWithFormat:@"Keychain Item Service:%@ Account:%@", self.service,self.account];
}

#pragma mark - Accessors
- (void)setPasswordObject:(id<NSCoding>)object {
    self.passwordData = [NSKeyedArchiver archivedDataWithRootObject:object];
}


- (id<NSCoding>)passwordObject {
    if ([self.passwordData length]) {
        return [NSKeyedUnarchiver unarchiveObjectWithData:self.passwordData];
    }
    return nil;
}


- (void)setPassword:(NSString *)password {
    self.passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
}


- (NSString *)password {
    if ([self.passwordData length]) {
        return [[NSString alloc] initWithData:self.passwordData encoding:NSUTF8StringEncoding];
    }
    return nil;
}

@end
