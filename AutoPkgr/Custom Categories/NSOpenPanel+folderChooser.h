//
//  NSOpenPanel+folderChooser.h
//  AutoPkgr
//
//  Created by Eldon on 6/7/15.
//  Copyright 2015 Eldon Ahrold
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

@interface NSOpenPanel (folderChooser)
/**
 *  Open a panel specifically designed to choose a folder
 *
 *  @param path  Path the open dialog should start at.
 *  @param reply reply block that takes one parameter, an NSString, that if the selected path is invalid will return nil.
 */
+ (void)folderChooserWithStartingPath:(NSString *)path
                                reply:(void (^)(NSString *selectedFolder))reply;

/**
 *  Open a panel specifically designed to choose a folder
 *
 *  @param path  Path the open dialog should start at.
 *  @param window modal window to present the panel on. can be nil.
 *  @param reply reply block that takes one parameter, an NSString, that if the selected path is invalid will return nil.
 */
+ (void)folderChooserWithStartingPath:(NSString *)path
                          modalWindow:(NSWindow *)window
                                reply:(void (^)(NSString *selectedFolder))reply;

@end
