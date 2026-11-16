#import <Foundation/Foundation.h>
NSURLSessionDataTask *WebKitFetch(NSString *url, NSUInteger limit, void (^done)(NSData *, NSHTTPURLResponse *, NSError *));
void WebKitSearchCall(NSString *name, NSString *profile, NSDictionary *args, void (^reply)(NSDictionary *));
NSString *WebKitResponseText(NSData *data, NSHTTPURLResponse *response);
void WebKitObserveRequests(void);

BOOL WebKitStoreRedirectAllowed(NSURL *url);
FOUNDATION_EXPORT void WebKitFetchStore(NSString *identifier, void (^done)(NSData *, NSHTTPURLResponse *, NSError *));
