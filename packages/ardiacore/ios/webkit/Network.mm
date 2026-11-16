#import "Network.h"
#import "../ArdiaLaunchConfig.h"
#import <objc/runtime.h>
#include <fcntl.h>
#include <unistd.h>

@interface WebKitRequestObserver : NSURLProtocol
@end

@implementation WebKitRequestObserver
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
  NSString *path = [ArdiaLaunchConfig.shared.dataDirectory stringByAppendingPathComponent:@"requests.jsonl"];
  if ([ArdiaLaunchConfig.shared testFlag:@"networkRequests"] && [@[@"http", @"https"] containsObject:request.URL.scheme.lowercaseString]) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:@{@"pid": @(getpid()), @"url": request.URL.absoluteString} options:0 error:nil];
    @synchronized(self) {
      int file = open(path.fileSystemRepresentation, O_WRONLY | O_CREAT | O_APPEND, 0600);
      if (file >= 0) {
        write(file, json.bytes, json.length);
        write(file, "\n", 1);
        close(file);
      }
    }
  }
  return NO;
}
+ (BOOL)canInitWithTask:(NSURLSessionTask *)task { return [self canInitWithRequest:task.currentRequest]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {}
- (void)stopLoading {}
@end

@interface WebKitRequest : NSObject <NSURLSessionDataDelegate>
@property NSURLSession *session;
@property NSMutableData *body;
@property NSUInteger limit;
@property BOOL storeOnly;
@property NSHTTPURLResponse *response;
@property(copy) void (^done)(NSData *, NSHTTPURLResponse *, NSError *);
@end

@implementation WebKitRequest
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completion {
  completion(!self.storeOnly || WebKitStoreRedirectAllowed(request.URL) ? request : nil);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completion {
  completion(!self.storeOnly || [challenge.protectionSpace.authenticationMethod isEqual:NSURLAuthenticationMethodServerTrust] ? NSURLSessionAuthChallengePerformDefaultHandling : NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completion {
  self.response = (NSHTTPURLResponse *)response;
  completion(response.expectedContentLength > (int64_t)self.limit ? NSURLSessionResponseCancel : NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
  if (data.length > self.limit - self.body.length) { [task cancel]; return; }
  [self.body appendData:data];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
  void (^done)(NSData *, NSHTTPURLResponse *, NSError *) = self.done;
  self.done = nil;
  if (done) done(error ? nil : self.body, self.response, error);
  [self.session finishTasksAndInvalidate];
  self.session = nil;
}
@end

void WebKitObserveRequests(void) {
  if (![ArdiaLaunchConfig.shared testFlag:@"networkRequests"]) return;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    Method getter = class_getInstanceMethod(NSURLSessionConfiguration.class, @selector(protocolClasses));
    IMP original = method_getImplementation(getter);
    method_setImplementation(getter, imp_implementationWithBlock(^NSArray *(NSURLSessionConfiguration *configuration) {
      NSArray *classes = ((NSArray *(*)(id, SEL))original)(configuration, @selector(protocolClasses));
      return [NSOrderedSet orderedSetWithArray:[@[WebKitRequestObserver.class] arrayByAddingObjectsFromArray:classes ?: @[]]].array;
    }));
  });
}

static NSURLSessionDataTask *Fetch(NSString *text, NSUInteger limit, BOOL storeOnly, void (^done)(NSData *, NSHTTPURLResponse *, NSError *)) {
  NSURL *url = [NSURL URLWithString:text];
  if (!url.host.length || ![@[@"http", @"https"] containsObject:url.scheme.lowercaseString]) {
    done(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil]);
    return nil;
  }
  WebKitRequest *request = [WebKitRequest new];
  request.storeOnly = storeOnly;
  request.body = [NSMutableData data]; request.limit = limit; request.done = done;
  NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  config.HTTPCookieStorage = nil;
  config.HTTPShouldSetCookies = NO;
  config.URLCredentialStorage = nil;
  config.URLCache = nil;
  config.timeoutIntervalForRequest = 10;
  config.timeoutIntervalForResource = storeOnly ? 60 : 10;
  request.session = [NSURLSession sessionWithConfiguration:config delegate:request delegateQueue:NSOperationQueue.mainQueue];
  NSURLSessionDataTask *task = [request.session dataTaskWithURL:url];
  [task resume];
  return task;
}

NSString *WebKitResponseText(NSData *data, NSHTTPURLResponse *response) {
  if (!data) return nil;
  NSStringEncoding encoding = NSUTF8StringEncoding;
  NSString *charset = response.textEncodingName;
  if (charset.length) {
    CFStringEncoding converted = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)charset);
    if (converted != kCFStringEncodingInvalidId) encoding = CFStringConvertEncodingToNSStringEncoding(converted);
  }
  return [[NSString alloc] initWithData:data encoding:encoding];
}

void WebKitSearchCall(NSString *name, NSString *profile, NSDictionary *args, void (^reply)(NSDictionary *)) {
  static NSMutableDictionary<NSString *, NSDictionary *> *pending = [NSMutableDictionary dictionary];
  NSNumber *identifier = [args[@"id"] isKindOfClass:NSNumber.class] ? args[@"id"] : nil;
  if (!identifier || identifier.doubleValue < 0 || !isfinite(identifier.doubleValue)) return reply(@{@"error": @"a suggestion request needs an id"});
  NSString *key = [NSString stringWithFormat:@"%@\n%@", profile, identifier];
  void (^stop)(NSString *) = ^(NSString *key) {
    NSDictionary *old = pending[key];
    if (!old) return;
    [pending removeObjectForKey:key];
    [(NSURLSessionDataTask *)old[@"task"] cancel];
    void (^done)(NSDictionary *) = old[@"reply"];
    done(@{@"stopped": @YES});
  };
  stop(key);
  if ([name isEqualToString:@"ac_search_suggest_stop"]) return reply(@{});
  NSString *url = [args[@"url"] isKindOfClass:NSString.class] ? args[@"url"] : @"";
  NSURL *parsed = [NSURL URLWithString:url];
  if (!parsed.host.length || ![@[@"http", @"https"] containsObject:parsed.scheme.lowercaseString]) return reply(@{@"error": @"a suggestion URL must be http or https"});
  while (pending.count >= 8) stop(pending.allKeys.firstObject);
  __block NSURLSessionDataTask *task;
  task = WebKitFetch(url, 256 * 1024, ^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
    if (pending[key][@"task"] != task) return;
    [pending removeObjectForKey:key];
    NSMutableDictionary *result = [@{@"status": @(response.statusCode)} mutableCopy];
    if (error) result[@"netError"] = @(error.code);
    NSString *body = WebKitResponseText(data, response);
    if (response.statusCode == 200 && body) result[@"body"] = body;
    reply(result);
  });
  pending[key] = @{@"task": task, @"reply": [reply copy]};
}

BOOL WebKitStoreRedirectAllowed(NSURL *url) {
  NSString *host = url.host.lowercaseString;
  return [url.scheme.lowercaseString isEqual:@"https"] && !url.user && !url.password && (!url.port || url.port.integerValue == 443) &&
    ([host isEqual:@"google.com"] || [host hasSuffix:@".google.com"] || [host isEqual:@"googleusercontent.com"] || [host hasSuffix:@".googleusercontent.com"]);
}
NSURLSessionDataTask *WebKitFetch(NSString *url, NSUInteger limit, void (^done)(NSData *, NSHTTPURLResponse *, NSError *)) {
  return Fetch(url, limit, NO, done);
}
void WebKitFetchStore(NSString *id, void (^done)(NSData *, NSHTTPURLResponse *, NSError *)) {
  if (id.length != 32 || [id rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnop"] invertedSet]].location != NSNotFound) {
    done(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorBadURL userInfo:nil]); return;
  }
  NSString *url = [NSString stringWithFormat:@"https://clients2.google.com/service/update2/crx?response=redirect&acceptformat=crx3&prodversion=157.0.0.0&x=id%%3D%@%%26uc", id];
  Fetch(url, 104857600, YES, done);
}
