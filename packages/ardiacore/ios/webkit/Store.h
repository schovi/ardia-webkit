#import <Foundation/Foundation.h>

BOOL WebKitPrivateProfile(NSString *profile);

@interface WebKitStore : NSObject
- (instancetype)initWithDirectory:(NSString *)directory profile:(NSString *)profile;
- (NSDictionary *)call:(NSString *)name args:(NSDictionary *)args;
@end

void WebKitStoreCall(NSString *name, NSString *profile, NSDictionary *args, void (^reply)(NSDictionary *));
