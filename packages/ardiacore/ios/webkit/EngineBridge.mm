#import "../ArdiaEngineBridge.h"
#import "../ArdiaLaunchConfig.h"
#import "Store.h"
#import "../ArdiaServices.h"
#import "Network.h"
#import "../ArdiaRuntime.h"

extern "C" void ArdiaWebKitPasswordsCall(NSString *, NSString *, NSDictionary *, void (^)(NSDictionary *));

extern "C" void ArdiaWebKitImportCookies(NSDictionary *, NSString *, void (^)(NSDictionary *));

@implementation ArdiaEngineBridge (WebKitDownloads)
+ (void)callWithSecret:(NSString *)name profile:(NSString *)profile args:(NSMutableData *)args completion:(void (^)(NSString *))completion {
  NSUInteger length = args.length;
  if (length && ((const char *)args.bytes)[length - 1] == 0) length--;
  const BOOL passwordCall = [@[@"ac_passwords_add", @"ac_passwords_update"] containsObject:name];
  if (passwordCall && length > 65536) {
    ardia_runtime::WipeSecret(args);
    return completion(@"{\"error\":\"secret arguments too large\"}");
  }
  NSMutableData *encoded = [args mutableCopy];
  encoded.length = length;
  NSDictionary *values = [NSJSONSerialization JSONObjectWithData:encoded options:0 error:nil];
  ardia_runtime::WipeSecret(encoded);
  ardia_runtime::WipeSecret(args);
  void (^answer)(NSDictionary *) = ^(NSDictionary *result) {
    completion([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:result options:0 error:nil] encoding:NSUTF8StringEncoding]);
  };
  if (![values isKindOfClass:NSDictionary.class]) return answer(@{@"error": @"invalid import arguments"});
  if ([@[@"ac_passwords_add", @"ac_passwords_update"] containsObject:name]) {
    return ArdiaWebKitPasswordsCall(name, profile, values, answer);
  }
  if (![name isEqual:@"ac_cookies_import"]) return answer(@{@"error": @"not imported: unsupported kind"});
  if (WebKitPrivateProfile(profile)) return answer(@{@"error": @"not imported: private profile"});
  ArdiaWebKitImportCookies(values, profile, answer);
}
+ (void)callForSecretReply:(NSString *)name profile:(NSString *)profile timeout:(NSTimeInterval)timeout completion:(void (^)(NSDictionary *))completion {
  completion(@{@"error": @"Password sync is unsupported on WebKit"});
}
+ (void)call:(NSString *)name profile:(NSString *)profile args:(NSString *)args completion:(void (^)(NSString *))completion {
  NSDictionary *values = args ? [NSJSONSerialization JSONObjectWithData:[args dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : @{};
  if (![values isKindOfClass:NSDictionary.class]) { completion(@"{\"error\":\"arguments must be an object\"}"); return; }
  void (^answer)(NSDictionary *) = ^(NSDictionary *result) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:result options:0 error:nil];
    completion([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
  };
  if ([@[@"ac_passwords_add", @"ac_passwords_update"] containsObject:name]) return answer(@{@"error": @"secret channel required"});
  if ([name hasPrefix:@"ac_passwords_"]) return ArdiaWebKitPasswordsCall(name, profile, values, answer);
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
  if ([@[@"ac_history_query", @"ac_history_add", @"ac_history_import", @"ac_history_delete_urls", @"ac_history_watch", @"ac_favicons_get", @"ac_favicons_set"] containsObject:name]) {
    return WebKitStoreCall(name, profile, values, answer);
  }
  if ([name isEqualToString:@"ac_search_suggest"] || [name isEqualToString:@"ac_search_suggest_stop"]) return WebKitSearchCall(name, profile, values, answer);
  static dispatch_once_t once;
  dispatch_once(&once, ^{ NSLog(@"[standin] +[ArdiaEngineBridge call:profile:args:completion:]"); });
  completion(nil);
}
@end
