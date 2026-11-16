#import "../ArdiaHost.h"
#import "../ArdiaChromeWindowHost.h"
#import "../ArdiaLaunchConfig.h"
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import <QuartzCore/QuartzCore.h>
#import "../ArdiaFieldTiming.h"
#import "Store.h"
#import "Network.h"
#import "Settings.h"

static __weak NSWindow *backgroundKeyWindow;
static const void *pageFullScreenKey = &pageFullScreenKey;
static const void *lightsCenterKey = &lightsCenterKey;
static const void *lightsTrailingKey = &lightsTrailingKey;
static BOOL (^shouldClose)(NSWindow *);
static BOOL (^refusesUnhandledKey)(NSWindow *, NSEvent *);
static void (^quitCancelled)(void);

WKWebView *WebKitPageAt(NSView *hit, NSView *root) {
  for (NSView *view = hit; view && view != root; view = view.superview)
    if ([view isKindOfClass:WKWebView.class]) return (WKWebView *)view;
  return nil;
}

NSString *WebKitModalAlertText(NSWindow *window) {
  NSMutableArray<NSString *> *text = [NSMutableArray array];
  NSMutableArray<NSView *> *pending = [NSMutableArray array];
  if (window.contentView) [pending addObject:window.contentView];
  while (pending.count) {
    NSView *view = pending.lastObject;
    [pending removeLastObject];
    [pending addObjectsFromArray:view.subviews];
    if ([view isKindOfClass:NSTextField.class] && ((NSTextField *)view).stringValue.length) [text addObject:((NSTextField *)view).stringValue];
  }
  return [text componentsJoinedByString:@" | "];
}

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
    class_addMethod(NSClassFromString(@"RCTTouchHandler"), NSSelectorFromString(@"gestureRecognizer:shouldAttemptToRecognizeWithEvent:"), imp_implementationWithBlock(^BOOL(id owner, NSGestureRecognizer *recognizer, NSEvent *event) {
      if (event.type != NSEventTypeLeftMouseDown) return YES;
      NSView *frame = event.window.contentView.superview;
      WKWebView *page = WebKitPageAt([frame hitTest:[frame convertPoint:event.locationInWindow fromView:nil]], recognizer.view);
      if (!page) return YES;
      SEL pressed = NSSelectorFromString(@"ardiaPagePressed");
      if ([page respondsToSelector:pressed]) [page performSelector:pressed];
      return NO;
    }), "B@:@@");
    NSApplication *application = NSApplication.sharedApplication;
    if (ArdiaLaunchConfig.shared.background) {
      [application setActivationPolicy:NSApplicationActivationPolicyProhibited];
      method_setImplementation(class_getInstanceMethod(NSWindow.class, @selector(makeKeyWindow)), imp_implementationWithBlock(^(NSWindow *window) {
        backgroundKeyWindow = window;
        [NSNotificationCenter.defaultCenter postNotificationName:NSWindowDidBecomeKeyNotification object:window];
      }));
      method_setImplementation(class_getInstanceMethod(NSWindow.class, @selector(makeKeyAndOrderFront:)), imp_implementationWithBlock(^(NSWindow *window, id sender) {
        backgroundKeyWindow = window;
        window.level = -1000;
        [window orderFront:nil];
      }));
    }
    if (ArdiaLaunchConfig.shared.background) {
      method_setImplementation(class_getInstanceMethod(NSApplication.class, @selector(keyWindow)), imp_implementationWithBlock(^NSWindow *(id app) { return backgroundKeyWindow; }));
      method_setImplementation(class_getInstanceMethod(NSWindow.class, @selector(isKeyWindow)), imp_implementationWithBlock(^BOOL(NSWindow *window) { return window == backgroundKeyWindow; }));
    }
    for (NSNotificationName name in @[NSWindowDidChangeOcclusionStateNotification, NSWindowDidMiniaturizeNotification, NSWindowDidDeminiaturizeNotification]) {
      [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        [NSNotificationCenter.defaultCenter postNotificationName:ArdiaWindowSeenDidChange object:note.object];
      }];
    }
    id<NSApplicationDelegate> delegate = makeDelegate();
    application.delegate = delegate;
    if (ArdiaLaunchConfig.shared.testInstance && !ArdiaLaunchConfig.shared.background) {
      NSTimer *watch = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        NSWindow *modal = NSApp.modalWindow;
        if (!modal) return;
        NSString *text = WebKitModalAlertText(modal);
        [text writeToFile:[ArdiaLaunchConfig.shared.dataDirectory stringByAppendingPathComponent:@"modal-alert.json"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [NSApp abortModal];
        [modal orderOut:nil];
        [timer invalidate];
        [NSTimer scheduledTimerWithTimeInterval:0 repeats:NO block:^(NSTimer *quit) { [NSApp terminate:nil]; }];
      }];
      [NSRunLoop.mainRunLoop addTimer:watch forMode:NSRunLoopCommonModes];
      [NSRunLoop.mainRunLoop addTimer:watch forMode:NSModalPanelRunLoopMode];
    }
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
NSValue *ArdiaTrafficLightsCenter(NSWindow *window) { return objc_getAssociatedObject(window, lightsCenterKey); }
BOOL ArdiaTrafficLightsTrailing(NSWindow *window) { return [objc_getAssociatedObject(window, lightsTrailingKey) boolValue]; }
BOOL ArdiaPerformReservedKey(NSEvent *event) {
  if (event.type != NSEventTypeKeyDown || !(event.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl))) return NO;
  if (refusesUnhandledKey && refusesUnhandledKey(event.window, event)) return YES;
  return [NSApp.mainMenu performKeyEquivalent:event];
}

@implementation ArdiaHost (Window)
+ (void (^)(void))quitCancelledHandler { return quitCancelled; }
+ (void)setQuitCancelledHandler:(void (^)(void))handler { quitCancelled = [handler copy]; }
+ (void)menuShortcutsChanged {}
@end

@implementation ArdiaChromeWindowHost (Window)
+ (void)setPageFullScreen:(BOOL)fullScreen inWindow:(NSWindow *)window { objc_setAssociatedObject(window, pageFullScreenKey, @(fullScreen), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
+ (BOOL)windowFullScreenIsForPage:(NSWindow *)window { return [objc_getAssociatedObject(window, pageFullScreenKey) boolValue]; }
+ (CGFloat)windowCornerRadius { return 19; }
+ (NSView *)rootViewOfWindow:(NSWindow *)window { return window.contentViewController.view; }
+ (NSView *)embeddedRootOfWindow:(NSWindow *)window { return [self rootViewOfWindow:window]; }
+ (void)removeRootViewOfWindow:(NSWindow *)window { window.contentViewController = nil; }
+ (void)setTrafficLightsCenter:(NSValue *)center trailing:(BOOL)trailing inWindow:(NSWindow *)window {
  objc_setAssociatedObject(window, lightsCenterKey, center, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(window, lightsTrailingKey, @(trailing), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [window layoutIfNeeded];
}
+ (void)moveTrafficLightsCenter:(NSValue *)center trailing:(BOOL)trailing inWindow:(NSWindow *)window { [self setTrafficLightsCenter:center trailing:trailing inWindow:window]; }
+ (void)closeWindow:(NSWindow *)window { [window close]; }
+ (BOOL (^)(NSWindow *))shouldCloseHandler { return shouldClose; }
+ (void)setShouldCloseHandler:(BOOL (^)(NSWindow *))handler { shouldClose = [handler copy]; }
+ (BOOL)windowShouldClose:(NSWindow *)window { return shouldClose ? shouldClose(window) : YES; }
+ (BOOL (^)(NSWindow *, NSEvent *))refusesUnhandledKeyHandler { return refusesUnhandledKey; }
+ (void)setRefusesUnhandledKeyHandler:(BOOL (^)(NSWindow *, NSEvent *))handler { refusesUnhandledKey = [handler copy]; }
+ (BOOL)userSeesWindow:(NSWindow *)window {
  return window && window.visible && !window.miniaturized && (ArdiaLaunchConfig.shared.background || (window.occlusionState & NSWindowOcclusionStateVisible));
}
@end

@implementation ArdiaChromeWindowHost (Dev)
+ (NSString *)devAction:(NSString *)action window:(NSWindow *)window {
  if (!ArdiaLaunchConfig.shared.testInstance) return @"unsupported";
  if ([action isEqual:@"state"]) {
    NSMutableArray *lights = [NSMutableArray array];
    for (NSInteger kind = NSWindowCloseButton; kind <= NSWindowZoomButton; kind++) {
      NSButton *button = [window standardWindowButton:(NSWindowButton)kind];
      NSRect frame = [button convertRect:button.bounds toView:nil];
      [lights addObject:@[@(NSMidX(frame)), @(window.frame.size.height - NSMidY(frame))]];
    }
    NSMutableArray *pages = [NSMutableArray array];
    NSMutableArray *pending = [NSMutableArray arrayWithObject:window.contentView];
    while (pending.count) {
      NSView *view = pending.lastObject;
      [pending removeLastObject];
      [pending addObjectsFromArray:view.subviews];
      if ([view isKindOfClass:WKWebView.class]) {
        WKWebView *page = (WKWebView *)view;
        NSRect frame = [page convertRect:page.bounds toView:nil];
        [pages addObject:@{@"x": @(NSMinX(frame)), @"y": @(window.frame.size.height - NSMaxY(frame)), @"width": @(frame.size.width), @"height": @(frame.size.height), @"gestures": @(page.allowsBackForwardNavigationGestures)}];
      }
    }
    NSDictionary *state = @{@"pages": pages, @"lights": lights, @"seen": @([self userSeesWindow:window]), @"responder": NSStringFromClass(window.firstResponder.class) ?: @"", @"visible": @(window.visible)};
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:state options:0 error:nil] encoding:NSUTF8StringEncoding];
  }
  if ([action isEqual:@"activate"]) {
    if (ArdiaLaunchConfig.shared.background) return @"foreground only";
    [NSTimer scheduledTimerWithTimeInterval:0 repeats:NO block:^(NSTimer *timer) {
      [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
      [NSApp activate];
      [window makeKeyAndOrderFront:nil];
      NSDictionary *state = @{@"policy": @(NSApp.activationPolicy), @"active": @(NSApp.isActive), @"key": @(window.isKeyWindow), @"canBecomeKey": @(window.canBecomeKeyWindow)};
      [[NSJSONSerialization dataWithJSONObject:state options:0 error:nil] writeToFile:[ArdiaLaunchConfig.shared.dataDirectory stringByAppendingPathComponent:@"activation.json"] atomically:YES];
    }];
    return @"ok";
  }
  if ([action isEqual:@"fullscreen"]) { [window toggleFullScreen:nil]; return @"ok"; }
  if ([action isEqual:@"close"]) { [window performClose:nil]; return @"ok"; }
  if ([action hasPrefix:@"resize:"]) {
    NSArray *size = [[action substringFromIndex:7] componentsSeparatedByString:@","];
    if (size.count != 2) return @"invalid size";
    [window setContentSize:NSMakeSize([size[0] doubleValue], [size[1] doubleValue])];
    return @"ok";
  }
  if ([action hasPrefix:@"key:"]) {
    NSArray *parts = [[action substringFromIndex:4] componentsSeparatedByString:@"|"];
    if (parts.count != 3) return @"invalid key";
    NSEventModifierFlags flags = [parts[2] longLongValue];
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil characters:parts[0] charactersIgnoringModifiers:parts[0] isARepeat:NO keyCode:[parts[1] intValue]];
    BOOL shortcut = (flags & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) != 0;
    if (!shortcut || (![window performKeyEquivalent:event] && ![NSApp.mainMenu performKeyEquivalent:event])) [window.firstResponder keyDown:event];
    NSEvent *up = [NSEvent keyEventWithType:NSEventTypeKeyUp location:NSZeroPoint modifierFlags:flags timestamp:event.timestamp windowNumber:window.windowNumber context:nil characters:parts[0] charactersIgnoringModifiers:parts[0] isARepeat:NO keyCode:event.keyCode];
    [window.firstResponder keyUp:up];
    return @"ok";
  }
  if ([action hasPrefix:@"mouse:"]) {
    NSArray *parts = [[action substringFromIndex:6] componentsSeparatedByString:@","];
    if (parts.count != 3) return @"invalid mouse";
    NSPoint point = NSMakePoint([parts[1] doubleValue], window.contentView.bounds.size.height - [parts[2] doubleValue]);
    BOOL right = [parts[0] hasPrefix:@"right"];
    BOOL down = [parts[0] hasSuffix:@"down"];
    NSEventType type = right ? (down ? NSEventTypeRightMouseDown : NSEventTypeRightMouseUp) : (down ? NSEventTypeLeftMouseDown : NSEventTypeLeftMouseUp);
    NSEvent *event = [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
    [NSApp postEvent:event atStart:NO];
    return @"ok";
  }
  NSView *view = window.contentView.superview ?: window.contentView;
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
  if (!pane) {
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = context;
    for (NSInteger kind = NSWindowCloseButton; kind <= NSWindowZoomButton; kind++) {
      NSButton *button = [window standardWindowButton:(NSWindowButton)kind];
      if (!button || button.hiddenOrHasHiddenAncestor) continue;
      NSBitmapImageRep *image = [button bitmapImageRepForCachingDisplayInRect:button.bounds];
      if (!image) continue;
      [button cacheDisplayInRect:button.bounds toBitmapImageRep:image];
      [image drawInRect:[button convertRect:button.bounds toView:view]];
    }
    [NSGraphicsContext restoreGraphicsState];
  }
  if (pane && !WebKitSnapshotHasContent(bitmap)) return @"blank pane snapshot";
  NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
  return [png writeToFile:path atomically:YES] ? @"ok" : @"write failed";
}
@end
