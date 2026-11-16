#import "../ArdiaServices.h"
#import "../ArdiaExtensionPackage.h"

@implementation ArdiaServices (WebKitExtensionPackage)
+ (NSDictionary *)inspectUnpacked:(NSString *)path {
  NSMutableDictionary *info = [ardia_extensions::ReadManifest(path) mutableCopy];
  if (!info[@"error"]) info[@"path"] = path;
  return info;
}
@end
