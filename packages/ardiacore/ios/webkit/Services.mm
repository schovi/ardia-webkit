#import "../ArdiaServices.h"
#import "Store.h"
#import "Settings.h"
#import "../ArdiaContentBlocker.h"

extern "C" NSDictionary *ArdiaWebKitContentBlockerState(void);

@implementation ArdiaServices (WebKitData)
+ (void)clearBrowsingData:(NSString *)profile types:(NSArray<NSString *> *)types since:(double)since completion:(void (^)(void))completion {
  if (![types containsObject:@"history"]) return completion();
  WebKitStoreCall(@"history.clear", profile, @{@"since": @(since)}, ^(NSDictionary *result) {
    if (result[@"error"]) NSLog(@"[webkit] history clear failed: %@", result[@"error"]);
    completion();
  });
}
+ (void)listExtensions:(NSString *)profile reply:(ArdiaServiceReply)reply {
  reply(@{@"extensions": @[]}, nil);
}
+ (void)searchEngineList:(NSString *)profile reply:(ArdiaServiceReply)reply {
  reply(@{@"list": @{@"engines": @[]}}, nil);
}
+ (void)zoomLevels:(NSString *)profile reply:(ArdiaServiceReply)reply {
  reply(WebKitProfileSettings(profile, @"zoom"), nil);
}
+ (void)setZoom:(double)zoom profile:(NSString *)profile host:(NSString *)host {
  if (!isfinite(zoom) || zoom < 0.25 || zoom > 5 || !host.length) return;
  WebKitSetProfileSetting(profile, @"zoom", host.lowercaseString, zoom == 1 ? nil : @(zoom));
}
+ (void)siteSettings:(NSString *)profile origin:(NSString *)origin reply:(ArdiaServiceReply)reply {
  NSDictionary *saved = WebKitProfileSettings(profile, @"sites")[origin] ?: @{};
  NSMutableDictionary *settings = [NSMutableDictionary dictionary];
  for (NSString *kind in @[@"camera", @"microphone", @"location", @"popups", @"sound"]) {
    NSString *fallback = [kind isEqual:@"sound"] ? @"allow" : [kind isEqual:@"popups"] ? @"block" : @"ask";
    settings[kind] = @{@"value": saved[kind] ?: fallback, @"isDefault": @(!saved[kind])};
  }
  reply(settings, nil);
}
+ (void)setSiteSetting:(NSString *)value profile:(NSString *)profile origin:(NSString *)origin type:(NSString *)type {
  if (![@[@"camera", @"microphone", @"location", @"popups", @"sound"] containsObject:type]) return;
  NSURL *url = [NSURL URLWithString:origin];
  if (!url.host.length || ![@[@"http", @"https"] containsObject:url.scheme]) return;
  NSMutableDictionary *settings = [WebKitProfileSettings(profile, @"sites")[origin] mutableCopy] ?: [NSMutableDictionary dictionary];
  if ([@[@"allow", @"block"] containsObject:value]) settings[type] = value;
  else [settings removeObjectForKey:type];
  WebKitSetProfileSetting(profile, @"sites", origin, settings.count ? settings : nil);
}
+ (void)siteSettingsOrigins:(NSString *)profile reply:(ArdiaServiceReply)reply {
  reply([WebKitProfileSettings(profile, @"sites").allKeys sortedArrayUsingSelector:@selector(compare:)], nil);
}
+ (void)resetSiteSettings:(NSString *)profile origin:(NSString *)origin {
  WebKitSetProfileSetting(profile, @"sites", origin, nil);
}
+ (void)watchDownloadEvents {}
+ (void)watchDownloads:(NSString *)profile {}

@end

NSDictionary *WebKitContentBlockerSettings(NSDictionary *state, NSDictionary *manifest) {
  NSMutableArray *lists = [NSMutableArray array];
  NSArray *selected = state[@"rulesets"] ?: @[];
  NSUInteger network = 0, cosmetic = 0, unsupported = 0;
  for (NSDictionary *list in manifest[@"rulesets"] ?: @[]) {
    NSString *identifier = list[@"id"];
    NSString *group = list[@"group"] ?: @"";
    NSString *category = @"ads";
    if ([identifier isEqual:@"easyprivacy"] || [group isEqual:@"privacy"]) category = @"trackers";
    else if ([identifier containsString:@"cookies"]) category = @"cookies";
    else if ([group isEqual:@"annoyances"]) category = @"annoyances";
    else if ([group isEqual:@"regions"]) category = @"regional";
    else if ([group isEqual:@"malware"]) category = @"security";
    BOOL enabled = [selected containsObject:identifier];
    if (enabled) {
      network += [list[@"converted"] unsignedIntegerValue];
      cosmetic += [list[@"cosmetic"] unsignedIntegerValue];
      unsupported += [list[@"skipped"] unsignedIntegerValue];
    }
    [lists addObject:@{@"id": identifier, @"title": list[@"name"] ?: identifier, @"category": category,
      @"enabled": @(enabled), @"defaultOn": @([list[@"enabled"] boolValue]),
      @"filters": @([list[@"converted"] unsignedIntegerValue] + [list[@"cosmetic"] unsignedIntegerValue])}];
  }
  NSMutableDictionary *stats = [@{@"ready": @([state[@"ready"] boolValue]), @"enabled": @([state[@"enabled"] boolValue]),
    @"networkFilters": @(network), @"cosmeticFilters": @(cosmetic), @"unsupportedFilters": @(unsupported),
    @"parseMs": @0, @"lookups": @0, @"averageLookupMicros": @0, @"maxLookupMicros": @0,
    @"blocked": state[@"blocked"] ?: @0} mutableCopy];
  if ([state[@"error"] isKindOfClass:NSString.class]) stats[@"error"] = state[@"error"];
  return @{@"enabled": @([state[@"enabled"] boolValue]), @"version": state[@"version"] ?: @"",
    @"lists": lists, @"allowedHosts": state[@"allowedHosts"] ?: @[], @"stats": stats};
}

@implementation ArdiaContentBlocker (WebKitSettings)
+ (void)state:(void (^)(NSDictionary<NSString *, id> *))completion {
  void (^answer)(void) = ^{
    NSURL *url = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"ContentRules/rulesets.json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSDictionary *manifest = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : @{};
    completion(WebKitContentBlockerSettings(ArdiaWebKitContentBlockerState(), manifest));
  };
  if (NSThread.isMainThread) answer();
  else dispatch_async(dispatch_get_main_queue(), answer);
}
+ (void)setEnabled:(BOOL)enabled completion:(void (^)(NSString *))completion {
  ArdiaWebKitContentBlockerState();
  [NSNotificationCenter.defaultCenter postNotificationName:@"ArdiaContentBlockerDidChange" object:nil userInfo:@{@"enabled": @(enabled)}];
  completion(nil);
}
+ (void)setList:(NSString *)listId enabled:(BOOL)enabled completion:(void (^)(NSString *))completion {
  ArdiaWebKitContentBlockerState();
  [NSNotificationCenter.defaultCenter postNotificationName:@"ArdiaContentBlockerDidChange" object:nil userInfo:@{@"list": listId, @"listEnabled": @(enabled)}];
  completion(nil);
}
+ (void)isAllowedOnHost:(NSString *)host completion:(void (^)(BOOL))completion {
  [self state:^(NSDictionary *state) {
    BOOL allowed = NO;
    for (NSString *domain in state[@"allowedHosts"]) if ([host isEqual:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]]) allowed = YES;
    completion(allowed);
  }];
}
+ (void)setAllowed:(BOOL)allowed onHost:(NSString *)host completion:(void (^)(NSString *))completion {
  ArdiaWebKitContentBlockerState();
  [NSNotificationCenter.defaultCenter postNotificationName:@"ArdiaContentBlockerDidChange" object:nil userInfo:@{@"host": host, @"allowed": @(allowed)}];
  completion(nil);
}

@end

NSView *WebKitFindNativeView(NSView *view, NSString *identifier) {
  if ([view respondsToSelector:NSSelectorFromString(@"nativeID")] && [[view valueForKey:@"nativeID"] isEqual:identifier]) return view;
  for (NSView *child in view.subviews) {
    NSView *found = WebKitFindNativeView(child, identifier);
    if (found) return found;
  }
  return nil;
}

BOOL WebKitSnapshotHasContent(NSBitmapImageRep *bitmap) {
  if (bitmap.pixelsWide < 2 || bitmap.pixelsHigh < 2) return NO;
  NSUInteger first[4], pixel[4];
  [bitmap getPixel:first atX:0 y:0];
  for (NSInteger y = 0; y < bitmap.pixelsHigh; y += MAX(1, bitmap.pixelsHigh / 200)) {
    for (NSInteger x = 0; x < bitmap.pixelsWide; x += MAX(1, bitmap.pixelsWide / 200)) {
      [bitmap getPixel:pixel atX:x y:y];
      for (NSUInteger channel = 0; channel < 3; channel++) if (labs((long)pixel[channel] - (long)first[channel]) > 16) return YES;
    }
  }
  return NO;
}
