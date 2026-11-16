#import "../ArdiaEngineBridge.h"
#import "../ArdiaLaunchConfig.h"

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
  static dispatch_once_t once;
  dispatch_once(&once, ^{ NSLog(@"[standin] +[ArdiaEngineBridge call:profile:args:completion:]"); });
  completion(nil);
}
@end
