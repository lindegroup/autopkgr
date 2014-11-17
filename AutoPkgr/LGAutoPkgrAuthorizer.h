#include <Foundation/Foundation.h>


@interface LGAutoPkgrAuthorizer : NSObject
+ (NSError *)checkAuthorization:(NSData *)authData command:(SEL)command;
+ (NSData  *)authorizeHelper;

@end
