#import "../ArdiaServices.h"
#import "Store.h"

@implementation ArdiaServices (WebKitData)
+ (void)clearBrowsingData:(NSString *)profile types:(NSArray<NSString *> *)types since:(double)since completion:(void (^)(void))completion {
  if (![types containsObject:@"history"]) return completion();
  WebKitStoreCall(@"history.clear", profile, @{@"since": @(since)}, ^(NSDictionary *result) {
    if (result[@"error"]) NSLog(@"[webkit] history clear failed: %@", result[@"error"]);
    completion();
  });
}
+ (void)searchEngineList:(NSString *)profile reply:(ArdiaServiceReply)reply {
  reply(@{@"list": @{@"engines": @[]}}, nil);
}
@end
