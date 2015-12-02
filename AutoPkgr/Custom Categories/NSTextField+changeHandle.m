//
//  NSTextField+changeHandle.m
//
//  Created by Eldon Ahrold on 12/2/15.
//  Copyright © 2015 EEAAPPS. All rights reserved.
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

#import "NSTextField+changeHandle.h"
#import <objc/runtime.h>

typedef void (^privateTextChangeBlock)(NSString *);
typedef void (^privateCompletionBlock)(void);

@interface NSTextField (_changeHandle) <NSTextFieldDelegate>
@property (copy, nonatomic) privateTextChangeBlock _textChanged;
@property (copy, nonatomic) privateCompletionBlock _editingStarted;
@property (copy, nonatomic) privateCompletionBlock _editingEnded;
@end

@implementation NSTextField (_changeHandle)
- (privateTextChangeBlock)_textChanged
{
    return objc_getAssociatedObject(self, @selector(_textChanged));
}
- (void)set_textChanged:(privateTextChangeBlock)_textChanged
{
    objc_setAssociatedObject(self, @selector(_textChanged), _textChanged, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (privateCompletionBlock)_editingStarted
{
    return objc_getAssociatedObject(self, @selector(_editingStarted));
}
- (void)set_editingStarted:(privateCompletionBlock)_editingStarted
{
    objc_setAssociatedObject(self, @selector(_editingStarted), _editingStarted, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (privateCompletionBlock)_editingEnded
{
    return objc_getAssociatedObject(self, @selector(_editingEnded));
}
- (void)set_editingEnded:(privateCompletionBlock)_editingEnded
{
    objc_setAssociatedObject(self, @selector(_editingEnded), _editingEnded, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
@end

@implementation NSTextField (changeHandle)

- (instancetype)editingStarted:(void (^)())block
{
    self._editingStarted = block;
    self.delegate = self;
    return self;
}

- (instancetype)textChanged:(void (^)(NSString *))block
{
    self._textChanged = block;
    self.delegate = self;
    return self;
}

- (instancetype)editingEnded:(void (^)())block
{
    self._editingEnded = block;
    self.delegate = self;
    return self;
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    privateTextChangeBlock pcb = self._textChanged;
    if (pcb) {
        pcb([notification.object stringValue]);
    }
}

- (void)controlTextDidBeginEditing:(NSNotification *)notification
{
    privateCompletionBlock pcb = self._editingStarted;
    if (pcb) {
       pcb();
    }
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    privateCompletionBlock pcb = self._editingEnded;
    if (pcb) {
        pcb();
    }
}

@end
