#import "../ios/webkit/Store.h"
#include <cassert>
#include <cstdio>

void CheckWebKitBookmarks(WebKitStore *store) {
  NSString *folder = @"10000000-0000-4000-8000-000000000001", *first = @"10000000-0000-4000-8000-000000000002", *second = @"10000000-0000-4000-8000-000000000003";
  NSDictionary *(^apply)(NSArray *) = ^NSDictionary *(NSArray *ops) { return [store call:@"ac_bookmarks_apply" args:@{@"ops": ops}]; };
  NSDictionary *(^tree)(void) = ^NSDictionary *{ return [store call:@"ac_bookmarks_tree" args:@{}]; };
  NSArray *adds = @[@{@"op": @"add", @"id": folder, @"parent": @"bar", @"k": @"f", @"t": @"Folder", @"a": @1234, @"key": @"legacy-folder"},
    @{@"op": @"add", @"id": first, @"parent": folder, @"u": @"https://one.example/", @"t": @"One"},
    @{@"op": @"add", @"id": second, @"parent": folder, @"u": @"https://two.example/", @"t": @"Two"}];
  assert([apply(adds)[@"applied"] intValue] == 3);
  assert([tree()[@"bar"][@"id"] length] == 36);
  assert([tree()[@"bar"][@"c"][0][@"key"] isEqual:@"legacy-folder"]);
  assert([tree()[@"bar"][@"c"][0][@"a"] intValue] == 1234);
  assert([apply(@[@{@"op": @"move", @"id": second, @"parent": folder, @"index": @0}])[@"applied"] intValue] == 1);
  assert([tree()[@"bar"][@"c"][0][@"c"][0][@"id"] isEqual:second]);
  apply(@[@{@"op": @"move", @"id": second, @"parent": folder, @"index": @99}]);
  assert([tree()[@"bar"][@"c"][0][@"c"][1][@"id"] isEqual:second]);
  NSDictionary *cycle = apply(@[@{@"op": @"move", @"id": folder, @"parent": folder}, @{@"op": @"remove", @"id": first}]);
  assert([cycle[@"skipped"] intValue] == 2);
  assert([apply(@[@{@"op": @"update", @"id": @"bar", @"t": @"No"}])[@"skipped"] intValue] == 1);
  NSDictionary *invalid = apply(@[@{@"op": @"add", @"id": @"10000000-0000-4000-8000-000000000004", @"parent": @"other", @"u": @"bad"}, @{@"op": @"update", @"id": first, @"t": @"Renamed", @"u": @"bad"}]);
  assert([invalid[@"invalid"] count] == 1 && [invalid[@"applied"] intValue] == 1);
  assert([tree()[@"bar"][@"c"][0][@"c"][0][@"t"] isEqual:@"Renamed"]);
  assert([tree()[@"bar"][@"c"][0][@"c"][0][@"u"] isEqual:@"https://one.example/"]);
  NSDictionary *before = tree();
  assert(apply(@[adds[0], @42])[@"error"]);
  assert([before isEqual:tree()]);
  NSMutableDictionary *absent = [adds[0] mutableCopy]; absent[@"ifAbsent"] = @YES; absent[@"t"] = @"Ignored";
  assert([apply(@[absent])[@"applied"] intValue] == 1 && [before isEqual:tree()]);
  NSMutableDictionary *replace = [adds[0] mutableCopy];
  replace[@"parent"] = @"other"; replace[@"t"] = @"Moved folder"; replace[@"a"] = @9999; replace[@"key"] = @"replacement-key";
  assert([apply(@[replace])[@"applied"] intValue] == 1);
  NSDictionary *moved = tree()[@"other"][@"c"][0];
  assert([moved[@"t"] isEqual:@"Moved folder"] && [moved[@"c"] count] == 2);
  assert([moved[@"key"] isEqual:@"legacy-folder"] && [moved[@"a"] intValue] == 1234);
  apply(@[@{@"op": @"move", @"id": folder, @"parent": @"bar"}]);
  assert([apply(@[@{@"op": @"add", @"id": @"bad", @"parent": @"bar", @"k": @"f"}])[@"skipped"] intValue] == 1);
  apply(@[@{@"op": @"move", @"id": folder, @"parent": @"other", @"index": @-1}]);
  assert([tree()[@"bar"][@"c"] count] == 0 && [tree()[@"other"][@"c"] count] == 1);
  apply(@[@{@"op": @"remove", @"id": folder}]);
  assert([tree()[@"other"][@"c"] count] == 0);
  assert([apply(@[@{@"op": @"update", @"id": first}])[@"skipped"] intValue] == 1);
  assert([store call:@"ac_bookmarks_export_html" args:@{@"path": @"relative.html"}][@"error"]);
  std::puts("PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion");
}
