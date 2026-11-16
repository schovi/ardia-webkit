#import "../ios/ArdiaHost.h"
#import "../ios/ArdiaEvents.h"
@implementation ArdiaHost
+ (NSString *)baseProfileOf:(NSString *)profile {
  NSRange at = [profile rangeOfString:@"@"];
  return at.location == NSNotFound ? @"" : [profile substringFromIndex:at.location + 1];
}
+ (NSString *)dataDirectory { return @(getenv("ARDIA_DATA_DIR")); }
@end
@implementation ArdiaEvents
+ (void)emit:(NSString *)name data:(NSDictionary *)data {}
@end
