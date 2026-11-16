#import "../ArdiaEngineBridge.h"
#import "../ArdiaLaunchConfig.h"
#import "Store.h"
#import "../ArdiaServices.h"
#import "Network.h"

@implementation ArdiaEngineBridge (WebKitDownloads)
+ (void)call:(NSString *)name profile:(NSString *)profile args:(NSString *)args completion:(void (^)(NSString *))completion {
  NSDictionary *values = args ? [NSJSONSerialization JSONObjectWithData:[args dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : @{};
  if (![values isKindOfClass:NSDictionary.class]) { completion(@"{\"error\":\"arguments must be an object\"}"); return; }
  void (^answer)(NSDictionary *) = ^(NSDictionary *result) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
  };
  if ([name isEqual:@"ac_downloads_set_settings"]) {
    if ([values[@"folder"] isKindOfClass:NSString.class] && [values[@"folder"] isAbsolutePath])
      WebKitSetProfileSetting(profile, @"downloads", @"folder", values[@"folder"]);
    if ([values[@"askWhereToSave"] isKindOfClass:NSNumber.class])
      WebKitSetProfileSetting(profile, @"downloads", @"askWhereToSave", @([values[@"askWhereToSave"] boolValue]));
    return answer(@{});
  }
  if ([name isEqual:@"ac_downloads_settings"]) {
    NSMutableDictionary *settings = [WebKitProfileSettings(profile, @"downloads") mutableCopy];
    if (!settings[@"folder"]) settings[@"folder"] = [ArdiaLaunchConfig.shared instance:@"downloadsDir"] ?: NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES).firstObject;
    if (!settings[@"askWhereToSave"]) settings[@"askWhereToSave"] = @NO;
    return answer(settings);
  }
  static NSDictionary *defaults = @{
    @"ac_extensions_watch_actions": @{},
    @"ac_extensions_load_health": @{@"dropped": @0, @"enabled": @0, @"disabled": @{}}
  };
  if (defaults[name]) return answer(defaults[name]);
  if ([name hasPrefix:@"ac_bookmarks_"]) return WebKitStoreCall(name, profile, values, answer);
  if ([@[@"ac_history_query", @"ac_history_add", @"ac_history_delete_urls", @"ac_history_watch", @"ac_favicons_get", @"ac_favicons_set"] containsObject:name]) {
    return WebKitStoreCall(name, profile, values, answer);
  }
  if ([name isEqualToString:@"ac_search_suggest"] || [name isEqualToString:@"ac_search_suggest_stop"]) return WebKitSearchCall(name, profile, values, answer);
  static dispatch_once_t once;
  dispatch_once(&once, ^{ NSLog(@"[standin] +[ArdiaEngineBridge call:profile:args:completion:]"); });
  completion(nil);
}
@end
