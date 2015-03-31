//
//  NSTextField+setStringValueSafe.h
//  AutoPkgr
//
//  Created by Eldon on 10/4/14.
//
//  Copyright 2014-2015 The Linde Group, Inc.
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

#import <Cocoa/Cocoa.h>

@interface NSTextField (setSafeStringValue)

/**
 *  (Custom Category) populate the text field with a string, but do not raise if the string passed in is nil
 *  @discussion this is useful when setting NSTextFields from defaults or data sources that may not have any values yet.
 *
 *  @param aString stringValue to set
 */
- (void)setSafeStringValue:(NSString *)safeStringValue;

/**
 *  (Custom Category) return nil from string value if it's a blank string
 *
 *  @discussion this is useful for conditionally checking values in subsequent if statements, since the default value returned from a NSTextField is @"" which will will return True.
 *
 *  @return stringValue if not blank
 */
- (NSString *)safeStringValue;

@end
