#import "../ios/webkit/Store.h"
#import "../ios/webkit/Network.h"
#import "../ios/webkit/Settings.h"
#import "../ios/ArdiaServices.h"
#import "../ios/ArdiaEngineBridge.h"
#import "../ios/ArdiaContentBlocker.h"
#import "../ios/ArdiaEvents.h"
#import "../ios/ArdiaLaunchConfig.h"
#import "../ios/ArdiaHost.h"
#import "../ios/ArdiaFavicons.h"
#include <cstdio>
#include <cstdlib>
#include <unistd.h>

static NSString *directory;
static void Check(bool value, const char *name) {
  if (!value) { std::fprintf(stderr, "FAIL %s\n", name); std::exit(1); }
}
@implementation ArdiaHost
+ (NSString *)dataDirectory { return directory; }
@end
@implementation ArdiaEvents
+ (void)emit:(NSString *)name data:(NSDictionary *)data {}
@end

@implementation ArdiaEngineBridge
@end
@implementation ArdiaServices
@end
@implementation ArdiaContentBlocker
@end
extern "C" NSDictionary *ArdiaWebKitContentBlockerState(void) { return @{}; }

@interface TestSettingsView : NSView
@property(copy) NSString *nativeID;
@end
@implementation TestSettingsView
@end

int main(int argc, const char **argv) {
  @autoreleasepool {
    Check(argc == 2, "scratch directory argument");
    directory = @(argv[1]);
    __block BOOL emptyExtensions = NO;
    [ArdiaServices listExtensions:@"" reply:^(id result, NSString *error) { emptyExtensions = !error && [result[@"extensions"] isEqual:@[]]; }];
    Check(emptyExtensions, "extensions list has a correctly shaped empty result");
    for (NSString *name in @[@"ac_bookmarks_watch", @"ac_extensions_watch_actions", @"ac_extensions_load_health", @"ac_bookmarks_tree"]) {
      __block NSDictionary *result;
      [ArdiaEngineBridge call:name profile:@"" args:@"{}" completion:^(NSString *json) {
        result = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
      }];
      Check(result != nil, "placeholder engine calls return JSON objects");
      if ([name isEqual:@"ac_bookmarks_tree"]) Check([result[@"bar"][@"c"] isEqual:@[]] && [result[@"other"][@"k"] isEqual:@"f"], "bookmark placeholder has both empty folder roots");
      if ([name isEqual:@"ac_extensions_load_health"]) Check([result[@"enabled"] intValue] == 0 && [result[@"disabled"] isKindOfClass:NSDictionary.class], "extension health placeholder shape");
    }
    NSDictionary *emptyBlocker = WebKitContentBlockerSettings(@{}, @{});
    Check([emptyBlocker[@"lists"] count] == 0 && [emptyBlocker[@"allowedHosts"] count] == 0, "empty blocker arrays");
    Check([emptyBlocker[@"stats"] isKindOfClass:NSDictionary.class] && ![emptyBlocker[@"stats"][@"ready"] boolValue], "empty blocker stats shape");
    NSDictionary *manifest = @{@"rulesets": @[
      @{@"id": @"easylist", @"name": @"EasyList", @"group": @"default", @"enabled": @YES, @"converted": @7, @"cosmetic": @3, @"skipped": @2},
      @{@"id": @"easyprivacy", @"group": @"default", @"enabled": @YES, @"converted": @5},
      @{@"id": @"annoyances-cookies", @"group": @"annoyances"}, @{@"id": @"regional", @"group": @"regions"},
      @{@"id": @"security", @"group": @"malware"}, @{@"id": @"social", @"group": @"annoyances"} ]};
    NSDictionary *blocker = WebKitContentBlockerSettings(@{@"ready": @YES, @"enabled": @YES, @"version": @"1", @"rulesets": @[@"easylist", @"easyprivacy"], @"allowedHosts": @[@"local.test"], @"compileMs": @12, @"blocked": @4, @"error": @"fixture"}, manifest);
    Check([blocker[@"lists"] count] == 6 && [blocker[@"lists"][0][@"title"] isEqual:@"EasyList"], "blocker list metadata");
    Check([blocker[@"lists"][0][@"filters"] intValue] == 10 && [blocker[@"lists"][0][@"enabled"] boolValue], "real selected list counts");
    NSArray *categories = [blocker[@"lists"] valueForKey:@"category"];
    Check([categories isEqual:@[@"ads", @"trackers", @"cookies", @"regional", @"security", @"annoyances"]], "blocker categories");
    Check([blocker[@"stats"][@"networkFilters"] intValue] == 12 && [blocker[@"stats"][@"cosmeticFilters"] intValue] == 3 && [blocker[@"stats"][@"blocked"] intValue] == 4, "blocker real statistics");
    Check([blocker[@"stats"][@"parseMs"] intValue] == 0 && [blocker[@"stats"][@"error"] isEqual:@"fixture"], "blocker default timing and real error");
    TestSettingsView *root = [[TestSettingsView alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    TestSettingsView *child = [[TestSettingsView alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    child.nativeID = @"settings-pane-fixture";
    [root addSubview:child];
    Check(WebKitFindNativeView(root, child.nativeID) == child && !WebKitFindNativeView(root, @"missing"), "snapshot selects the pane root only");
    NSBitmapImageRep *blank = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:16 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    memset(blank.bitmapData, 255, blank.bytesPerRow * blank.pixelsHigh);
    Check(!WebKitSnapshotHasContent(blank), "blank pane rejected");
    NSUInteger black[] = {0,0,0,255};
    [blank setPixel:black atX:8 y:8];
    Check(WebKitSnapshotHasContent(blank), "rendered pane accepted");
    NSString *cache = [directory stringByAppendingPathComponent:@"switches-cache.json"];
    [@"{\"version\":1,\"switches\":{\"sidebarSlide\":false}}" writeToFile:cache atomically:YES encoding:NSUTF8StringEncoding error:nil];
    ArdiaLaunchConfig *launch = [[ArdiaLaunchConfig alloc] initWithEnvironment:@{@"ARDIA_DATA_DIR": directory} signedForDistribution:^BOOL { return NO; }];
    Check([launch switchOn:@"sidebarSlide"], "native switches ignore cached remote values");
    ArdiaLaunchConfig *override = [[ArdiaLaunchConfig alloc] initWithEnvironment:@{@"ARDIA_SWITCHES": @"sidebarSlide=off"} signedForDistribution:^BOOL { return NO; }];
    Check(![override switchOn:@"sidebarSlide"], "native switches keep explicit local overrides");
    NSString *observed = [directory stringByAppendingPathComponent:@"requests.jsonl"];
    WebKitObserveRequests();
    Class observer = NSClassFromString(@"WebKitRequestObserver");
    Check(observer != Nil, "request observer linked");
    NSArray *protocols = NSURLSessionConfiguration.defaultSessionConfiguration.protocolClasses;
    Check([protocols containsObject:observer], "observer installed in session configurations");
    Check([NSSet setWithArray:protocols].count == protocols.count, "observer appears once after configuration copies");
    for (NSString *url in @[@"http://127.0.0.1/control", @"https://example.invalid/control", @"file:///tmp/control"]) {
      Check(![observer canInitWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]], "observer never handles or blocks a request");
    }
    NSArray *lines = [[NSString stringWithContentsOfFile:observed encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
    Check(lines.count == 3, "observer records only HTTP and HTTPS");
    NSDictionary *entry = [NSJSONSerialization JSONObjectWithData:[lines[0] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    Check([entry[@"url"] isEqual:@"http://127.0.0.1/control"] && [entry[@"pid"] intValue] == getpid(), "observer records URL and owning process");
    NSString *stores = [directory stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    Check(WebKitPrivateProfile(@"incognito:w1@work"), "private profile parser");
    Check(!WebKitPrivateProfile(@"work"), "regular profile parser");
    NSString *privateFolder = [stores stringByAppendingPathComponent:@"private"];
    Check([[WebKitStore alloc] initWithDirectory:privateFolder profile:@"incognito:w1@work"] == nil, "private store refused");
    Check(![NSFileManager.defaultManager fileExistsAtPath:privateFolder], "private writes nothing");
    WebKitStore *store = [[WebKitStore alloc] initWithDirectory:stores profile:@""];
    NSDictionary *pages = @{@"pages": @[@{@"u": @"https://one.example/", @"t": @"First", @"v": @[@1000, @3000]}, @{@"u": @"https://two.example/", @"t": @"Second", @"v": @[@2000]}], @"toleranceMs": @0};
    Check([[store call:@"ac_history_add" args:pages][@"added"] intValue] == 3, "visits added");
    Check([[store call:@"ac_history_add" args:pages][@"added"] intValue] == 0, "duplicate visits ignored");
    NSDictionary *near = @{@"pages": @[@{@"u": @"https://one.example/", @"v": @[@3010]}], @"toleranceMs": @20};
    Check([[store call:@"ac_history_add" args:near][@"added"] intValue] == 0, "tolerance respected");
    Check([[store call:@"ac_history_add" args:@{@"pages": @[@42, @{@"u": @"file:///tmp/test", @"v": @[@5000]}, @{@"u": @"https://invalid.example/", @"v": @[@"bad", @-1]}]}][@"added"] intValue] == 0, "malformed visits ignored");
    NSArray *entries = [store call:@"ac_history_query" args:@{}][@"entries"];
    Check(entries.count == 2, "two URLs");
    Check([entries[0][@"u"] isEqual:@"https://one.example/"], "newest URL first");
    Check([entries[0][@"v"] isEqual:@[@1000, @3000]], "visit times ascend");
    Check([entries[0][@"t"] isEqual:@"First"], "title preserved");
    Check([[store call:@"ac_history_query" args:@{@"maxUrls": @1, @"maxVisits": @1}][@"entries"][0][@"v"] isEqual:@[@3000]], "query limits");
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:16 pixelsHigh:16 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    NSDictionary *icon = @{@"page": @"https://one.example/", @"icon": @"https://one.example/favicon.png", @"png": [png base64EncodedStringWithOptions:0]};
    Check([[store call:@"ac_favicons_set" args:icon][@"stored"] boolValue], "favicon stored");
    Check(![[store call:@"ac_favicons_set" args:@{@"page": @"https://one.example/", @"icon": @"bad", @"png": @"invalid"}][@"stored"] boolValue], "invalid favicon rejected");
    store = nil;
    store = [[WebKitStore alloc] initWithDirectory:stores profile:@""];
    Check([[store call:@"ac_history_query" args:@{}][@"entries"] count] == 2, "history survives reopen");
    NSDictionary *found = [store call:@"ac_favicons_get" args:@{@"pages": @[@"https://one.example/"], @"icons": @[@"https://one.example/favicon.png"]}];
    Check([found[@"pages"] count] == 1 && [found[@"icons"] count] == 1, "favicon survives reopen");
    WebKitStore *work = [[WebKitStore alloc] initWithDirectory:stores profile:@"../../work"];
    Check([[work call:@"ac_history_query" args:@{}][@"entries"] count] == 0, "profiles isolated and paths encoded");
    [store call:@"ac_history_delete_urls" args:@{@"urls": @[@"https://two.example/"]}];
    Check([[store call:@"ac_history_query" args:@{}][@"entries"] count] == 1, "URL deleted");
    Check([[store call:@"ac_history_add" args:pages][@"added"] intValue] == 0, "deleted visits cannot return from delayed writes");
    double future = NSDate.date.timeIntervalSince1970 * 1000 + 10000;
    NSDictionary *fresh = @{@"pages": @[@{@"u": @"https://two.example/", @"t": @"Second", @"v": @[@(future)]}]};
    Check([[store call:@"ac_history_add" args:fresh][@"added"] intValue] == 1, "new visits to deleted URLs remain allowed");
    [store call:@"history.clear" args:@{@"since": @2000}];
    Check([[store call:@"ac_history_query" args:@{}][@"entries"][0][@"v"] isEqual:@[@1000]], "clear respects time range");
    Check([[store call:@"ac_history_add" args:@{@"pages": @[@{@"u": @"https://old.example/", @"v": @[@1000]}]}][@"added"] intValue] == 1, "range clear preserves older pending visits");
    [store call:@"history.clear" args:@{}];
    Check([[store call:@"ac_history_query" args:@{}][@"entries"] count] == 0, "clear empties history");
    NSHTTPURLResponse *latin = [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://suggest.example/"] statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"text/javascript; charset=ISO-8859-1"}];
    Check([WebKitResponseText([@"météo" dataUsingEncoding:NSISOLatin1StringEncoding], latin) isEqual:@"météo"], "suggestions respect response charset");
    Check([WebKitResponseText([@"天気" dataUsingEncoding:NSUTF8StringEncoding], nil) isEqual:@"天気"], "suggestions default to UTF-8");
    store = nil;
    store = [[WebKitStore alloc] initWithDirectory:stores profile:@""];
    Check([[store call:@"ac_history_add" args:pages][@"added"] intValue] == 0, "cleared visits cannot return from delayed writes");
    Check([[store call:@"ac_history_add" args:fresh][@"added"] intValue] == 1, "visits after clearing remain allowed");
    __block BOOL invalid = NO;
    Check(WebKitFetch(@"file:///tmp/test", 100, ^(NSData *data, NSHTTPURLResponse *response, NSError *error) { invalid = error != nil && data == nil; }) == nil && invalid, "network URL validation");
    __block BOOL badIdentifier = NO;
    WebKitSearchCall(@"ac_search_suggest", @"", @{@"id": @-1}, ^(NSDictionary *reply) { badIdentifier = reply[@"error"] != nil; });
    Check(badIdentifier, "suggestion id validation");
    __block BOOL badIcon = NO;
    [ArdiaFavicons fetch:@"data:image/png;base64,invalid" profile:@"" name:nil completion:^(NSDictionary *result) { badIcon = result == nil; }];
    Check(badIcon, "favicon parser rejects malformed data");
    store = nil; work = nil;
    [NSFileManager.defaultManager removeItemAtPath:stores error:nil];
    std::puts("PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots");
  }
}
