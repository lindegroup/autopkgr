//
// AHHelpPopover.h
//
// Created by Eldon on 6/11/15.
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