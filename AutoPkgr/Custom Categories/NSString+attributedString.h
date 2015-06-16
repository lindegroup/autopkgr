//
//  NSString+attributedCopy.h
//  AutoPkgr
//
//  Created by Eldon on 6/15/15.
//

#import <Foundation/Foundation.h>

@interface NSString (attributedString)
@property (copy, nonatomic, readonly) NSAttributedString *attributed_copy;
@property (copy, nonatomic, readonly) NSMutableAttributedString *attributed_mutableCopy;
- (NSAttributedString *)attributed_with:(NSDictionary *)attributes;
- (NSAttributedString *)attributed_withLink:(NSString *)urlString;
@end

@interface NSMutableAttributedString (attributedString)
/**
 *  Add attributes to any matching string
 *
 *  @param name   Attribute name
 *  @param value  Attribute value
 *  @param string String to match
 */
- (void)attributed_addAttribute:(NSString *)name value:(id)value toString:(NSString *)string;
- (void)attributed_makeString:(NSString *)string linkTo:(NSString *)urlString;
- (void)attributed_makeStringALink:(NSString *)string;

@end