#import "Store.h"
#import "../ArdiaEvents.h"
#import "../ArdiaHost.h"
#import <CommonCrypto/CommonDigest.h>
#include <sqlite3.h>
#include <stdexcept>
#include <cmath>

BOOL WebKitPrivateProfile(NSString *profile) { return [profile hasPrefix:@"incognito"]; }

namespace {
NSString *Text(id value) { return [value isKindOfClass:NSString.class] ? value : @""; }
NSArray *List(id value) { return [value isKindOfClass:NSArray.class] ? value : @[]; }
double Number(id value, double fallback = 0) {
  return [value isKindOfClass:NSNumber.class] && std::isfinite([value doubleValue]) ? [value doubleValue] : fallback;
}
bool WebURL(NSString *text) {
  NSURL *url = [NSURL URLWithString:text];
  return url.host.length && [@[@"http", @"https"] containsObject:url.scheme.lowercaseString];
}
class Statement {
 public:
  sqlite3_stmt *value = nullptr;
  Statement(sqlite3 *database, const char *sql) {
    if (sqlite3_prepare_v2(database, sql, -1, &value, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(database));
  }
  ~Statement() { sqlite3_finalize(value); }
  void text(int index, NSString *text) { sqlite3_bind_text(value, index, text.UTF8String, -1, SQLITE_TRANSIENT); }
  void number(int index, double number) { sqlite3_bind_double(value, index, number); }
  bool step() {
    int status = sqlite3_step(value);
    if (status != SQLITE_ROW && status != SQLITE_DONE) throw std::runtime_error(sqlite3_errmsg(sqlite3_db_handle(value)));
    return status == SQLITE_ROW;
  }
  void reset() { sqlite3_reset(value); sqlite3_clear_bindings(value); }
  NSString *string(int index) { const char *text = (const char *)sqlite3_column_text(value, index); return text ? @(text) : @""; }
  double number(int index) { return sqlite3_column_double(value, index); }
};
void Execute(sqlite3 *database, const char *sql) {
  if (sqlite3_exec(database, sql, nullptr, nullptr, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(database));
}
NSString *FileName(NSString *profile) {
  if (!profile.length) return @"default.sqlite3";
  NSData *data = [profile dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *name = [NSMutableString string];
  for (unsigned char byte : digest) [name appendFormat:@"%02x", byte];
  return [name stringByAppendingString:@".sqlite3"];
}
}

@implementation WebKitStore {
  sqlite3 *_database;
  NSString *_profile;
}
- (instancetype)initWithDirectory:(NSString *)directory profile:(NSString *)profile {
  if (WebKitPrivateProfile(profile)) return nil;
  if ((self = [super init])) {
    _profile = profile;
    NSError *error;
    if (![NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error])
      throw std::runtime_error(error.localizedDescription.UTF8String);
    NSString *path = [directory stringByAppendingPathComponent:FileName(profile)];
    if (sqlite3_open(path.fileSystemRepresentation, &_database) != SQLITE_OK) throw std::runtime_error("cannot open the profile store");
    Execute(_database, "PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=3000;"
      "CREATE TABLE IF NOT EXISTS pages(url TEXT PRIMARY KEY,title TEXT NOT NULL,visits INTEGER NOT NULL,last REAL NOT NULL);"
      "CREATE INDEX IF NOT EXISTS pages_last ON pages(last DESC);"
      "CREATE TABLE IF NOT EXISTS visits(url TEXT REFERENCES pages(url) ON DELETE CASCADE,at REAL,PRIMARY KEY(url,at));"
      "CREATE TABLE IF NOT EXISTS icons(url TEXT PRIMARY KEY,png TEXT NOT NULL);"
      "CREATE TABLE IF NOT EXISTS page_icons(page TEXT PRIMARY KEY,icon TEXT NOT NULL);");
  }
  return self;
}
- (void)dealloc { if (_database) sqlite3_close(_database); }
- (void)emit:(NSArray *)changes {
  if (!changes.count) return;
  NSDictionary *event = @{@"profile": _profile, @"kind": @"batch", @"changes": changes};
  dispatch_async(dispatch_get_main_queue(), ^{ [ArdiaEvents emit:@"history.changed" data:event]; });
}
- (NSDictionary *)call:(NSString *)name args:(NSDictionary *)args {
  if ([name isEqualToString:@"ac_history_watch"]) return @{};
  if ([name isEqualToString:@"ac_history_query"]) {
    int maxUrls = (int)MAX(0, MIN(50000, Number(args[@"maxUrls"], 5000)));
    int maxVisits = (int)MAX(0, MIN(1000, Number(args[@"maxVisits"], 50)));
    Statement pages(_database, "SELECT url,title,visits FROM pages ORDER BY last DESC LIMIT ?");
    pages.number(1, maxUrls);
    Statement visits(_database, "SELECT at FROM visits WHERE url=? ORDER BY at DESC LIMIT ?");
    NSMutableArray *entries = [NSMutableArray array];
    while (pages.step()) {
      NSString *url = pages.string(0);
      visits.text(1, url); visits.number(2, maxVisits);
      NSMutableArray *times = [NSMutableArray array];
      while (visits.step()) [times insertObject:@(visits.number(0)) atIndex:0];
      visits.reset();
      [entries addObject:@{@"u": url, @"t": pages.string(1), @"n": @(pages.number(2)), @"v": times}];
    }
    return @{@"entries": entries};
  }
  if ([name isEqualToString:@"ac_history_add"]) {
    Statement existing(_database, "SELECT 1 FROM visits WHERE url=? AND at BETWEEN ? AND ? LIMIT 1");
    Statement page(_database, "INSERT INTO pages VALUES(?,?,1,?) ON CONFLICT(url) DO UPDATE SET title=CASE WHEN excluded.title='' THEN title ELSE excluded.title END,visits=visits+1,last=MAX(last,excluded.last)");
    Statement visit(_database, "INSERT INTO visits VALUES(?,?)");
    double tolerance = MAX(0, Number(args[@"toleranceMs"], 1000));
    NSMutableArray *changes = [NSMutableArray array];
    int added = 0;
    Execute(_database, "BEGIN IMMEDIATE");
    try {
      for (id value in List(args[@"pages"])) {
        if (![value isKindOfClass:NSDictionary.class]) continue;
        NSString *url = Text(value[@"u"]), *title = Text(value[@"t"]);
        if (!WebURL(url)) continue;
        double lastAdded = 0;
        for (id time in List(value[@"v"])) {
          double at = Number(time);
          if (at <= 0) continue;
          existing.text(1, url); existing.number(2, at - tolerance); existing.number(3, at + tolerance);
          bool found = existing.step(); existing.reset();
          if (found) continue;
          page.text(1, url); page.text(2, title); page.number(3, at); page.step(); page.reset();
          visit.text(1, url); visit.number(2, at); visit.step(); visit.reset();
          added++; lastAdded = MAX(lastAdded, at);
        }
        if (lastAdded > 0) {
          Statement count(_database, "SELECT visits FROM pages WHERE url=?"); count.text(1, url); count.step();
          [changes addObject:@{@"kind": @"visit", @"u": url, @"t": title, @"n": @(count.number(0)), @"at": @(lastAdded)}];
        }
      }
      Execute(_database, "COMMIT");
    } catch (...) { Execute(_database, "ROLLBACK"); throw; }
    if (changes.count > 2000) changes = [NSMutableArray arrayWithObject:@{@"kind": @"deleted", @"all": @YES, @"urls": @[]}];
    [self emit:changes];
    return @{@"added": @(added)};
  }
  if ([name isEqualToString:@"ac_history_delete_urls"]) {
    Statement remove(_database, "DELETE FROM pages WHERE url=?");
    NSMutableArray *urls = [NSMutableArray array];
    Execute(_database, "BEGIN IMMEDIATE");
    try {
      for (id value in List(args[@"urls"])) {
        NSString *url = Text(value);
        if (!url.length) continue;
        remove.text(1, url); remove.step(); remove.reset(); [urls addObject:url];
      }
      Execute(_database, "COMMIT");
    } catch (...) { Execute(_database, "ROLLBACK"); throw; }
    [self emit:@[@{@"kind": @"deleted", @"all": @NO, @"urls": urls}]];
    return @{};
  }
  if ([name isEqualToString:@"history.clear"]) {
    Statement remove(_database, "DELETE FROM visits WHERE at>=?"); remove.number(1, Number(args[@"since"]));
    Execute(_database, "BEGIN IMMEDIATE");
    try {
      remove.step();
      Execute(_database, "DELETE FROM pages WHERE NOT EXISTS(SELECT 1 FROM visits WHERE visits.url=pages.url);"
        "UPDATE pages SET visits=(SELECT COUNT(*) FROM visits WHERE visits.url=pages.url),last=(SELECT MAX(at) FROM visits WHERE visits.url=pages.url);");
      Execute(_database, "COMMIT");
    } catch (...) { Execute(_database, "ROLLBACK"); throw; }
    [self emit:@[@{@"kind": @"deleted", @"all": @YES, @"urls": @[]}]];
    return @{};
  }
  if ([name isEqualToString:@"ac_favicons_set"]) {
    NSString *page = Text(args[@"page"]), *icon = Text(args[@"icon"]), *png = Text(args[@"png"]);
    NSData *data = [[NSData alloc] initWithBase64EncodedString:png options:0];
    const unsigned char signature[] = {137,80,78,71,13,10,26,10};
    if (!WebURL(page) || !icon.length || data.length < 8 || data.length > 2*1024*1024 || memcmp(data.bytes, signature, 8)) return @{@"stored": @NO};
    Statement save(_database, "INSERT OR REPLACE INTO icons VALUES(?,?)"); save.text(1, icon); save.text(2, png); save.step();
    Statement link(_database, "INSERT OR REPLACE INTO page_icons VALUES(?,?)"); link.text(1, page); link.text(2, icon); link.step();
    return @{@"stored": @YES};
  }
  if ([name isEqualToString:@"ac_favicons_get"]) {
    NSMutableDictionary *pages = [NSMutableDictionary dictionary], *icons = [NSMutableDictionary dictionary];
    Statement page(_database, "SELECT icons.png,icons.url FROM page_icons JOIN icons ON icons.url=page_icons.icon WHERE page=?");
    for (id value in List(args[@"pages"])) {
      NSString *url = Text(value); page.text(1, url);
      if (page.step()) pages[url] = @{@"png": page.string(0), @"icon": page.string(1)};
      page.reset();
    }
    Statement icon(_database, "SELECT png FROM icons WHERE url=?");
    for (id value in List(args[@"icons"])) {
      NSString *url = Text(value); icon.text(1, url);
      if (icon.step()) icons[url] = @{@"png": icon.string(0)};
      icon.reset();
    }
    return @{@"pages": pages, @"icons": icons};
  }
  return @{@"error": @"unsupported store call"};
}
@end

void WebKitStoreCall(NSString *name, NSString *profile, NSDictionary *args, void (^reply)(NSDictionary *)) {
  if (WebKitPrivateProfile(profile)) {
    if ([name isEqualToString:@"ac_history_query"]) return reply(@{@"entries": @[]});
    if ([name isEqualToString:@"ac_history_add"]) return reply(@{@"added": @0});
    if ([name isEqualToString:@"ac_favicons_set"]) return reply(@{@"stored": @NO});
    if ([name isEqualToString:@"ac_favicons_get"]) return reply(@{@"pages": @{}, @"icons": @{}});
    return reply(@{});
  }
  static dispatch_queue_t queue = dispatch_queue_create("ardia.webkit.store", DISPATCH_QUEUE_SERIAL);
  dispatch_async(queue, ^{
    @autoreleasepool {
      NSDictionary *result;
      try {
        NSString *directory = [ArdiaHost.dataDirectory stringByAppendingPathComponent:@"Stores"];
        WebKitStore *store = [[WebKitStore alloc] initWithDirectory:directory profile:profile];
        result = [store call:name args:args];
      } catch (const std::exception &error) { result = @{@"error": @(error.what())}; }
      dispatch_async(dispatch_get_main_queue(), ^{ reply(result); });
    }
  });
}
