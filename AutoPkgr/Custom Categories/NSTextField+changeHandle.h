//
//  NSTextField+changeHandle.h
//
//  Created by Eldon Ahrold on 12/2/15.
//  Copyright 2015 Eldon Ahrold, Inc.
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

#import <Cocoa/Cocoa.h>

/**
 *  Class Category that creates some nice chainable blocks for NSTextField. @note Setting blocks in this category will make the text field become it's own delegate.
 */
@interface NSTextField (changeHandle)
/**
 *  Execute a block when the editing begins
 *
 *  @param block block executed when editing begins. This block takes no parameters and has no return
 *
 *  @return self
 */
- (instancetype)editingStarted:(void (^)(NSTextField *))block;

/**
 *  Execute a block when the string value changes
 *
 *  @param block block executed when the string changes. This block takes one parameters NSString and has no return
 *
 *  @return self
 */
- (instancetype)textChanged:(void (^)(NSString *newVal))block;

/**
 *  Execute a block when the editing ends
 *
 *  @param block block executed when editing ends. This block takes no parameters and has no return
 *
 *  @return self
 */
- (instancetype)editingEnded:(void (^)(NSTextField *))block;
@end
