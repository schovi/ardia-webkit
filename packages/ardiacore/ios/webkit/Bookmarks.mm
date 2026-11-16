#import "Bookmarks.h"
#import "../ArdiaEvents.h"
#include <stdexcept>
#include <cmath>

namespace {
NSString *Text(id value) { return [value isKindOfClass:NSString.class] ? value : nil; }
double Number(id value, double fallback) {
  return [value isKindOfClass:NSNumber.class] && std::isfinite([value doubleValue]) ? [value doubleValue] : fallback;
}
class Query {
 public:
  sqlite3_stmt *value = nullptr;
  Query(sqlite3 *database, const char *sql) {
    if (sqlite3_prepare_v2(database, sql, -1, &value, nullptr) != SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(database));
  }
  ~Query() { sqlite3_finalize(value); }
  void bind(int index, NSString *text) { sqlite3_bind_text(value, index, text.UTF8String, -1, SQLITE_TRANSIENT); }
  bool step() {
    int status = sqlite3_step(value);
    if (status != SQLITE_ROW && status != SQLITE_DONE) throw std::runtime_error(sqlite3_errmsg(sqlite3_db_handle(value)));
    return status == SQLITE_ROW;
  }
  NSString *text(int index) { return @((const char *)sqlite3_column_text(value, index)); }
};
NSMutableSet *Watched() {
  static NSMutableSet *profiles = [NSMutableSet set];
  return profiles;
}
BOOL ValidURL(NSString *text) {
  if (!text.length || [text rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return NO;
  NSURL *url = [NSURL URLWithString:text];
  if (!url.scheme.length) return NO;
  return ![@[@"http", @"https", @"ftp"] containsObject:url.scheme.lowercaseString] || url.host.length > 0;
}
NSDictionary *NodeValue(NSDictionary *nodes, NSString *identifier, int depth) {
  if (depth > 512) return nil;
  NSMutableDictionary *node = [nodes[identifier] mutableCopy];
  [node removeObjectsForKeys:@[@"parent", @"root"]];
  if (node[@"c"]) {
    NSMutableArray *children = [NSMutableArray array];
    for (NSString *child in node[@"c"]) {
      NSDictionary *value = NodeValue(nodes, child, depth + 1);
      if (!value) return nil;
      [children addObject:value];
    }
    node[@"c"] = children;
  }
  return node;
}
NSString *Escape(NSString *text) {
  for (NSArray *pair in @[@[@"&", @"&amp;"], @[@"<", @"&lt;"], @[@">", @"&gt;"], @[@"\"", @"&quot;"]])
    text = [text stringByReplacingOccurrencesOfString:pair[0] withString:pair[1]];
  return text;
}
void AppendHTML(NSMutableString *html, NSDictionary *node, NSString *role) {
  long long added = [node[@"a"] doubleValue] / 1000;
  if ([node[@"k"] isEqual:@"u"]) {
    [html appendFormat:@"<DT><A HREF=\"%@\" ADD_DATE=\"%lld\">%@</A>\n", Escape(node[@"u"]), added, Escape(node[@"t"])];
  } else {
    [html appendFormat:@"<DT><H3 ADD_DATE=\"%lld\"%@>%@</H3>\n<DL><p>\n", added, role, Escape(node[@"t"])];
    for (NSDictionary *child in node[@"c"]) AppendHTML(html, child, @"");
    [html appendString:@"</DL><p>\n"];
  }
}
void Save(sqlite3 *database, NSDictionary *nodes) {
  Query remove(database, "DELETE FROM bookmarks"); remove.step();
  Query save(database, "INSERT INTO bookmarks(id,parent,position,value) VALUES(?,?,?,?)");
  for (NSString *identifier in nodes) {
    NSMutableDictionary *node = [nodes[identifier] mutableCopy];
    NSString *parent = node[@"parent"];
    NSUInteger position = parent.length ? [nodes[parent][@"c"] indexOfObject:identifier] : [node[@"root"] unsignedIntegerValue];
    [node removeObjectsForKeys:@[@"parent", @"c", @"root"]];
    NSData *json = [NSJSONSerialization dataWithJSONObject:node options:0 error:nil];
    save.bind(1, identifier); save.bind(2, parent); sqlite3_bind_int64(save.value, 3, position);
    save.bind(4, [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]); save.step();
    sqlite3_reset(save.value); sqlite3_clear_bindings(save.value);
  }
}
int Apply(NSMutableDictionary *nodes, NSDictionary *roots, NSDictionary *op) {
  NSString *identifier = op[@"id"], *kind = op[@"op"];
  identifier = roots[identifier] ?: identifier;
  NSMutableDictionary *node = nodes[identifier];
  BOOL permanent = node && ![node[@"parent"] length];
  if ([kind isEqual:@"remove"]) {
    if (!node || permanent) return 0;
    [nodes[node[@"parent"]][@"c"] removeObject:identifier];
    NSMutableArray *pending = [NSMutableArray arrayWithObject:identifier];
    while (pending.count) {
      NSString *next = pending.lastObject; [pending removeLastObject];
      [pending addObjectsFromArray:nodes[next][@"c"] ?: @[]]; [nodes removeObjectForKey:next];
    }
    return 1;
  }
  if (![kind isEqual:@"update"]) {
    NSString *parent = Text(op[@"parent"]) ?: @""; parent = roots[parent] ?: parent;
    NSMutableArray *children = nodes[parent][@"c"];
    if (!children) return 0;
    if ([kind isEqual:@"add"] && node && [op[@"ifAbsent"] isKindOfClass:NSNumber.class] && [op[@"ifAbsent"] boolValue]) return 1;
    if ([kind isEqual:@"move"] || node) {
      if (!node || permanent) return 0;
      for (NSString *at = parent; at.length; at = nodes[at][@"parent"]) if ([at isEqual:identifier]) return 0;
      [nodes[node[@"parent"]][@"c"] removeObject:identifier];
    } else {
      NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:identifier];
      if (!uuid || ![uuid.UUIDString.lowercaseString isEqual:identifier]) return 0;
      BOOL folder = [Text(op[@"k"]) isEqual:@"f"];
      if (!folder && !ValidURL(Text(op[@"u"]))) return -1;
      double added = Number(op[@"a"], 0);
      node = [@{@"id": identifier, @"k": folder ? @"f" : @"u", @"t": @"", @"a": @(floor(added > 0 ? added : NSDate.date.timeIntervalSince1970 * 1000))} mutableCopy];
      if (folder) node[@"c"] = [NSMutableArray array];
      if ([Text(op[@"key"]) length]) node[@"key"] = op[@"key"];
      nodes[identifier] = node;
    }
    NSUInteger index = (NSUInteger)MAX(0, MIN(Number(op[@"index"], children.count), (double)children.count));
    [children insertObject:identifier atIndex:index]; node[@"parent"] = parent;
    if ([kind isEqual:@"move"]) return 1;
  } else if (!node || permanent) return 0;
  if (Text(op[@"t"]) || [kind isEqual:@"add"]) node[@"t"] = Text(op[@"t"]) ?: @"";
  if ([node[@"k"] isEqual:@"u"] && ValidURL(Text(op[@"u"]))) node[@"u"] = op[@"u"];
  return 1;
}
}

NSDictionary *WebKitBookmarksCall(sqlite3 *database, NSString *name, NSString *profile, NSDictionary *args) {
  if ([name isEqual:@"ac_bookmarks_watch"]) { [Watched() addObject:profile]; return @{}; }
  NSArray *ops = [args[@"ops"] isKindOfClass:NSArray.class] ? args[@"ops"] : @[];
  if ([name isEqual:@"ac_bookmarks_apply"]) {
    NSUInteger index = 0;
    for (id op in ops) {
      if (![op isKindOfClass:NSDictionary.class] || !Text(op[@"id"]) || ![@[@"add", @"move", @"update", @"remove"] containsObject:Text(op[@"op"]) ?: @""])
        return @{@"error": [NSString stringWithFormat:@"bad op at %lu", index]};
      index++;
    }
  }
  Query begin(database, "BEGIN IMMEDIATE"); begin.step();
  @try {
    try {
      NSMutableDictionary *nodes = [NSMutableDictionary dictionary], *roots = [NSMutableDictionary dictionary];
      Query read(database, "SELECT id,parent,position,value FROM bookmarks ORDER BY parent,position");
      while (read.step()) {
        NSMutableDictionary *node = [NSJSONSerialization JSONObjectWithData:[read.text(3) dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        node[@"parent"] = read.text(1);
        if ([node[@"k"] isEqual:@"f"]) node[@"c"] = [NSMutableArray array];
        if (![read.text(1) length]) { node[@"root"] = @(sqlite3_column_int(read.value, 2)); roots[[node[@"root"] intValue] == 0 ? @"bar" : @"other"] = read.text(0); }
        nodes[read.text(0)] = node;
      }
      Query order(database, "SELECT id,parent FROM bookmarks WHERE parent<>'' ORDER BY parent,position");
      for (NSString *identifier in nodes) [nodes[identifier][@"c"] removeAllObjects];
      while (order.step()) [nodes[order.text(1)][@"c"] addObject:order.text(0)];
      BOOL fresh = !roots.count;
      if (fresh) {
        for (NSString *role in @[@"bar", @"other"]) {
          NSString *identifier = NSUUID.UUID.UUIDString.lowercaseString; roots[role] = identifier;
          nodes[identifier] = [@{@"id": identifier, @"parent": @"", @"root": [role isEqual:@"bar"] ? @0 : @1, @"k": @"f", @"t": [role isEqual:@"bar"] ? @"Bookmarks Bar" : @"Other Bookmarks", @"a": @0, @"c": [NSMutableArray array]} mutableCopy];
        }
      }
      NSDictionary *result;
      if ([name isEqual:@"ac_bookmarks_apply"]) {
        int applied = 0; NSMutableArray *invalid = [NSMutableArray array];
        for (NSDictionary *op in ops) {
          int status = Apply(nodes, roots, op);
          if (!status) break;
          if (status < 0) [invalid addObject:op[@"id"]]; else applied++;
        }
        result = @{@"applied": @(applied), @"skipped": @(ops.count - applied - invalid.count), @"invalid": invalid};
        Save(database, nodes);
      } else {
        NSDictionary *bar = NodeValue(nodes, roots[@"bar"], 0), *other = NodeValue(nodes, roots[@"other"], 0);
        result = bar && other ? @{@"bar": bar, @"other": other} : @{@"error": @"bookmarks nested too deep"};
        if ([name isEqual:@"ac_bookmarks_export_html"] && !result[@"error"]) {
          NSString *path = Text(args[@"path"]);
          if (!path.isAbsolutePath) result = @{@"error": @"an absolute path required"};
          else {
            NSMutableString *html = [NSMutableString stringWithString:@"<!DOCTYPE NETSCAPE-Bookmark-file-1>\n<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">\n<TITLE>Bookmarks</TITLE>\n<H1>Bookmarks</H1>\n<DL><p>\n"];
            AppendHTML(html, bar, @" PERSONAL_TOOLBAR_FOLDER=\"true\""); AppendHTML(html, other, @" UNFILED_BOOKMARKS_FOLDER=\"true\"");
            [html appendString:@"</DL><p>\n"];
            result = [html writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil] ? @{} : @{@"error": @"couldn't write the file"};
          }
        }
        if (fresh) Save(database, nodes);
      }
      Query commit(database, "COMMIT"); commit.step();
      if (fresh && [Watched() containsObject:profile]) dispatch_async(dispatch_get_main_queue(), ^{ [ArdiaEvents emit:@"bookmarks.changed" data:@{@"profile": profile}]; });
      return result;
    } catch (...) { Query rollback(database, "ROLLBACK"); rollback.step(); throw; }
  } @catch (NSException *error) { Query rollback(database, "ROLLBACK"); rollback.step(); @throw; }
}
