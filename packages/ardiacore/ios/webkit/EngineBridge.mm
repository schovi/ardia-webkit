#import "../ArdiaEngineBridge.h"
#import "../ArdiaLaunchConfig.h"
#import "Store.h"
#import "Network.h"

@implementation ArdiaEngineBridge (WebKitDownloads)
+ (void)call:(NSString *)name profile:(NSString *)profile args:(NSString *)args completion:(void (^)(NSString *))completion {
  if ([name isEqualToString:@"ac_downloads_settings"]) {
    NSString *folder = [ArdiaLaunchConfig.shared instance:@"downloadsDir"];
    if (!folder) folder = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES).firstObject;
    NSDictionary *settings = @{@"folder": folder, @"askWhereToSave": @NO};
    NSData *data = [NSJSONSerialization dataWithJSONObject:settings options:0 error:nil];
    completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    return;
  }
  NSDictionary *values = args ? [NSJSONSerialization JSONObjectWithData:[args dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : @{};
  if (![values isKindOfClass:NSDictionary.class]) { completion(@"{\"error\":\"arguments must be an object\"}"); return; }
  void (^answer)(NSDictionary *) = ^(NSDictionary *result) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
  };
  if ([@[@"ac_history_query", @"ac_history_add", @"ac_history_delete_urls", @"ac_history_watch", @"ac_favicons_get", @"ac_favicons_set"] containsObject:name]) {
    return WebKitStoreCall(name, profile, values, answer);
  }
  if ([name isEqualToString:@"ac_search_suggest"] || [name isEqualToString:@"ac_search_suggest_stop"]) return WebKitSearchCall(name, profile, values, answer);
  static dispatch_once_t once;
  dispatch_once(&once, ^{ NSLog(@"[standin] +[ArdiaEngineBridge call:profile:args:completion:]"); });
  completion(nil);
}
@end
