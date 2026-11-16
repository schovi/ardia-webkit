#import <Foundation/Foundation.h>
#include <sqlite3.h>
NSDictionary *WebKitBookmarksCall(sqlite3 *database, NSString *name, NSString *profile, NSDictionary *args);
