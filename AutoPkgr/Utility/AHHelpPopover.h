//
//  AHHelpPopover.h
//  AutoPkgr
//
//  Created by Eldon Ahrold on 6/11/15.
//  Copyright 2015 Eldon Ahrold
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
 *  Popover for help text (or any other string.)
 */
@interface AHHelpPopover : NSPopover

/**
 *  Title of the help message, optional. Can be nil.
 */
@property (copy, nonatomic) NSString *helpTitle;

/**
 *  Body of the help message.
 */
@property (copy, nonatomic) NSString *helpText;

/**
 *  Attributed help text for the message. Setting this will override helpText.
 */
@property (copy, nonatomic) NSAttributedString *attributedHelpText;

/**
 *  Link to a remote help site. Can be nil.
 */
@property (copy, nonatomic) NSURL *helpURL;

/**
 *  The view to anchor the popover to.
 */
@property (copy, nonatomic) NSView *sender;

/**
 *  The font used to display the title text. Can be nil.
 */
@property (nonatomic) NSFont *helpTitleFont;

/**
 *  The font used to display the help text. Unused if setting text using -attributedHelpText.
 */
@property (nonatomic) NSFont *helpTextFont;

/**
 *  Width for the popover.
 */
@property (assign) NSInteger width;

/**
 *  Preferred edge to display on the sender. Defaults to NSMinYEdge.
 */
@property (nonatomic) NSRectEdge senderEdge;

/**
 *  How the text should be aligned.
 */
@property (nonatomic) NSTextAlignment textAlignment;

/**
 *  Block executed once the popover has closed.
 */
@property (copy) void (^completionHandler)();


/**
 *  Initialize help popover with reference to an NSView
 *
 *  @param sender Object to anchor the popover to.
 *
 *  @return initialized object.
 */
- (instancetype)initWithSender:(NSView *)sender;

/**
 *  Open the popover.
 */
- (void)openPopover;

/**
 *  Open the popover with a completion block.
 *
 *  @param complete block executed when popover closes.
 */
- (void)openPopoverWithCompletionHandler:(void (^)())complete;

/**
 *  Open the popover.
 *
 *  @param sender Button on which to anchor the popover
 *  @param format Format string for the help text.
 */
- (void)openPopoverFromButton:(NSButton *)sender witHelpTextFormat:(NSString *)format,... NS_FORMAT_FUNCTION(2, 3);

/**
 *  Open the popover.
 *
 *  @param sender Button on which to anchor the popover
 *  @param attributedHelpText Attributed string to display in the popover.
 */
- (void)openPopoverFromButton:(NSButton *)sender witAttributeHelpText:(NSAttributedString *)attributedHelpText;

@end

/**
 *  A Help Button interface specifically designed to open an popover window.
 */
@interface AHHelpPopoverButton : NSButton

/**
 *  Help text to apply.
 */
@property (copy, nonatomic) NSString *helpText;
- (void)helpTextWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);


/**
 *  Title for the help, shown in bold. (optional)
 */
@property (copy, nonatomic) NSString *helpTitle;

/**
 *  URL link string to displayed at the bottom of the help. (optional)
 */
@property (copy, nonatomic) NSString *helpLink;
@end