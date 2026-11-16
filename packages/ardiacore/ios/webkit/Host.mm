#import "../ArdiaHost.h"
#import "../ArdiaChromeWindowHost.h"
#import "../ArdiaLaunchConfig.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "../ArdiaFieldTiming.h"
#import "Store.h"
#import "Network.h"
#import "Settings.h"

void ArdiaWebViewsSetFieldTiming(BOOL on) {}

@implementation ArdiaHost (WebKitData)
+ (NSArray *)chromeWindows {
  NSMutableArray *windows = [NSMutableArray array];
  for (NSWindow *window in NSApp.windows) {
    if (!window.contentViewController) continue;
    [windows addObject:@{@"profile": @"", @"window": @(window.windowNumber), @"frame": NSStringFromRect(window.frame),
      @"alpha": @(window.alphaValue), @"key": @(window.isKeyWindow), @"canBecomeKey": @(window.canBecomeKeyWindow),
      @"visible": @(window.isVisible), @"parentWindow": @(window.parentWindow.windowNumber), @"chromeWindows": @0,
      @"anchorBrowserId": @0, @"anyTabBrowserId": @0, @"ready": @YES, @"active": @(window.isMainWindow),
      @"pageInsets": @[@0,@0,@0,@0], @"hosting": @YES, @"group": @"", @"hasRoot": @YES, @"translucent": @NO}];
  }
  return windows;
}
+ (BOOL)isPrivateProfile:(NSString *)profile { return WebKitPrivateProfile(profile); }
+ (NSString *)baseProfileOf:(NSString *)profile {
  if (!WebKitPrivateProfile(profile)) return profile ?: @"";
  NSRange at = [profile rangeOfString:@"@"];
  return at.location == NSNotFound ? @"" : [profile substringFromIndex:at.location + 1];
}
+ (NSString *)dataDirectory {
  return [(ArdiaLaunchConfig.shared.dataDirectory ?: ArdiaLaunchConfig.shared.configDirectory) stringByAppendingPathComponent:@"WebKit"];
}
@end

@implementation ArdiaHost (Launch)
+ (int)runWithArgc:(int)argc argv:(char **)argv delegate:(id<NSApplicationDelegate> (^)(void))makeDelegate {
  @autoreleasepool {
    WebKitObserveRequests();
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

@implementation ArdiaChromeWindowHost (Dev)
+ (NSString *)devAction:(NSString *)action window:(NSWindow *)window {
  if (!ArdiaLaunchConfig.shared.testInstance) return @"unsupported";
  NSView *view = window.contentView;
  NSString *path;
  BOOL pane = [action hasPrefix:@"snapshotPane:"];
  if (pane) {
    NSArray *parts = [[action substringFromIndex:@"snapshotPane:".length] componentsSeparatedByString:@"|"];
    if (parts.count != 2) return @"invalid pane snapshot";
    view = WebKitFindNativeView(view, parts[0]);
    if (!view || view.bounds.size.width < 1 || view.bounds.size.height < 1 || !view.subviews.count) return @"pane root not rendered";
    path = parts[1];
  } else if ([action hasPrefix:@"snapshotFrame:"]) path = [action substringFromIndex:@"snapshotFrame:".length];
  else return @"unsupported";
  NSString *scratch = [ArdiaLaunchConfig.shared.dataDirectory stringByAppendingString:@"/"];
  if (![path.stringByStandardizingPath hasPrefix:scratch]) return @"snapshot must stay in scratch data";
  CGFloat scale = window.backingScaleFactor;
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nullptr pixelsWide:view.bounds.size.width*scale pixelsHigh:view.bounds.size.height*scale bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
  NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];
  if (!context || !view.layer) return @"no window layer";
  CGContextRef cg = context.CGContext;
  CGContextSetFillColorWithColor(cg, window.backgroundColor.CGColor);
  CGContextFillRect(cg, CGRectMake(0,0,bitmap.pixelsWide,bitmap.pixelsHigh));
  CGContextScaleCTM(cg, scale, scale);
  if (view.isFlipped || view.layer.geometryFlipped) {
    CGContextTranslateCTM(cg, 0, view.bounds.size.height);
    CGContextScaleCTM(cg, 1, -1);
  }
  [view.layer renderInContext:cg];
  if (pane && !WebKitSnapshotHasContent(bitmap)) return @"blank pane snapshot";
  NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  return [png writeToFile:path atomically:YES] ? @"ok" : @"write failed";
}
@end
