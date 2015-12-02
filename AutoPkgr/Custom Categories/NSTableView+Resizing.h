//
//  NSTableView+Resizing.h
//
//  Created by Eldon Ahrold on 12/2/15.
//  Copyright © 2015 EEAAPPS
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

@interface NSTableView (Resizing)
/**
 *  Animated Rezising of a table view to a specific height
 *  @note For this to work you the table view must have a NSLayoutAttributeHeight constratint set on the tableView.
 *  @param height New height of the tableView
 */
- (void)resized_Height:(NSInteger)height;

/**
 *  Animated Rezising of a table view to a specific width
 *  @note For this to work you the table view must have a NSLayoutAttributeWith constratint set on the tableView.
 *  @param height New width of the tableView
 */
- (void)resized_Width:(NSInteger)width;

@end
