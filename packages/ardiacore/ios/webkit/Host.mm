#import "../ArdiaHost.h"
#import "../ArdiaChromeWindowHost.h"
#import "../ArdiaLaunchConfig.h"
#import <objc/runtime.h>
#import "../ArdiaFieldTiming.h"

void ArdiaWebViewsSetFieldTiming(BOOL on) {}

@implementation ArdiaHost (WebKitData)
+ (NSString *)dataDirectory {
  return [(ArdiaLaunchConfig.shared.dataDirectory ?: ArdiaLaunchConfig.shared.configDirectory) stringByAppendingPathComponent:@"WebKit"];
}
@end

@implementation ArdiaHost (Launch)
+ (int)runWithArgc:(int)argc argv:(char **)argv delegate:(id<NSApplicationDelegate> (^)(void))makeDelegate {
  @autoreleasepool {
    NSApplication *application = NSApplication.sharedApplication;
    if (ArdiaLaunchConfig.shared.background) {
      [application setActivationPolicy:NSApplicationActivationPolicyProhibited];
      method_setImplementation(class_getInstanceMethod(NSWindow.class, @selector(makeKeyWindow)), imp_implementationWithBlock(^(NSWindow *window) {}));
      method_setImplementation(class_getInstanceMethod(NSWindow.class, @selector(makeKeyAndOrderFront:)), imp_implementationWithBlock(^(NSWindow *window, id sender) {
        window.level = -1000;
        [window orderFront:nil];
      }));
    }
    id<NSApplicationDelegate> delegate = makeDelegate();
    application.delegate = delegate;
    [application run];
    return 0;
  }
}
+ (NSDictionary *)senderOfOpenedURL:(NSString *)url { return nil; }
+ (BOOL)holdsIncomingLinks { return NO; }
+ (NSDictionary *)launchMarks { return @{}; }
+ (void)setHoldIncomingLinks:(BOOL)hold hooksStamp:(NSString *)stamp {}
+ (NSString *)fileStampOfDescriptor:(int)fd { return @""; }
+ (NSString *)missingFileStamp { return @""; }
@end

NSNotificationName const ArdiaWindowSeenDidChange = @"ArdiaWindowSeenDidChange";
NSView *ArdiaWindowRootView(NSWindow *window) { return window.contentViewController.view ?: window.contentView; }
NSValue *ArdiaTrafficLightsCenter(NSWindow *window) { return nil; }
BOOL ArdiaTrafficLightsTrailing(NSWindow *window) { return NO; }
BOOL ArdiaPerformReservedKey(NSEvent *event) { return NO; }
