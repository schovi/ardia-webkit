#import "../ios/ArdiaHost.h"
#import "../ios/ArdiaChromeWindowHost.h"
#import "../ios/ArdiaEvents.h"
#import "../ios/ArdiaLaunchConfig.h"
#import "../ios/ArdiaServices.h"
#import "../ios/ArdiaContentBlocker.h"
#import <WebKit/WebKit.h>
#include <cassert>
#include <cstdio>

@implementation ArdiaHost
@end
@implementation ArdiaChromeWindowHost
@end
@implementation ArdiaEvents
+ (void)emit:(NSString *)name data:(NSDictionary *)data {}
@end

@implementation ArdiaServices
@end
@implementation ArdiaContentBlocker
@end
extern "C" NSArray *ArdiaWebKitLoadedProfiles(void) { return @[]; }
extern "C" void ArdiaWebKitReleaseProfile(NSString *) {}
extern "C" NSDictionary *ArdiaWebKitContentBlockerState(void) { return @{}; }

@interface KeyTestWindow : NSWindow
@end
@implementation KeyTestWindow
- (BOOL)performKeyEquivalent:(NSEvent *)event { return YES; }
@end
@interface KeyTestView : NSView
@property NSInteger keys;
@end
@implementation KeyTestView
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent *)event { self.keys++; }
- (void)keyUp:(NSEvent *)event {}
@end

WKWebView *WebKitPageAt(NSView *hit, NSView *root);
NSString *WebKitModalAlertText(NSWindow *window);

int main() {
  @autoreleasepool {
    [NSApplication.sharedApplication setActivationPolicy:NSApplicationActivationPolicyProhibited];
    NSWindow *window = [[KeyTestWindow alloc] initWithContentRect:NSMakeRect(0,0,800,600) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    assert([ArdiaHost.engineInfo[@"engine"] isEqual:@"WebKit"]);
    assert([ArdiaHost.engineInfo[@"webkitVersion"] length] > 0);
    assert([ArdiaHost isPrivateProfile:@"incognito:test@work"]);
    assert([[ArdiaHost baseProfileOf:@"incognito:test@work"] isEqual:@"work"]);
    assert([[ArdiaHost baseProfileOf:@"work"] isEqual:@"work"]);
    assert([ArdiaChromeWindowHost windowShouldClose:window]);
    __block NSWindow *asked;
    ArdiaChromeWindowHost.shouldCloseHandler = ^BOOL(NSWindow *sender) { asked = sender; return NO; };
    assert(![ArdiaChromeWindowHost windowShouldClose:window] && asked == window);
    ArdiaChromeWindowHost.shouldCloseHandler = nil;
    assert([ArdiaChromeWindowHost windowShouldClose:window]);
    assert(![ArdiaChromeWindowHost windowFullScreenIsForPage:window]);
    [ArdiaChromeWindowHost setPageFullScreen:YES inWindow:window];
    assert([ArdiaChromeWindowHost windowFullScreenIsForPage:window]);
    [ArdiaChromeWindowHost setPageFullScreen:NO inWindow:window];
    assert(![ArdiaChromeWindowHost windowFullScreenIsForPage:window]);
    assert([WebKitModalAlertText(nil) isEqual:@""]);
    assert([[ArdiaChromeWindowHost devAction:@"activate" window:window] isEqual:@"foreground only"]);
    assert(![ArdiaChromeWindowHost userSeesWindow:nil]);
    assert(![ArdiaChromeWindowHost userSeesWindow:window]);
    NSValue *center = [NSValue valueWithPoint:NSMakePoint(40,30)];
    [ArdiaChromeWindowHost setTrafficLightsCenter:center trailing:YES inWindow:window];
    assert([ArdiaTrafficLightsCenter(window) isEqual:center] && ArdiaTrafficLightsTrailing(window));
    [ArdiaChromeWindowHost moveTrafficLightsCenter:nil trailing:NO inWindow:window];
    assert(!ArdiaTrafficLightsCenter(window) && !ArdiaTrafficLightsTrailing(window));
    NSViewController *controller = [NSViewController new];
    controller.view = [[NSView alloc] initWithFrame:NSMakeRect(0,0,800,600)];
    window.contentViewController = controller;
    assert([ArdiaChromeWindowHost rootViewOfWindow:window] == controller.view);
    assert([ArdiaChromeWindowHost embeddedRootOfWindow:window] == controller.view);
    [ArdiaChromeWindowHost removeRootViewOfWindow:window];
    assert(![ArdiaChromeWindowHost rootViewOfWindow:window]);
    __block BOOL cancelled = NO;
    ArdiaHost.quitCancelledHandler = ^{ cancelled = YES; };
    assert(!cancelled && ArdiaHost.quitCancelledHandler);
    ArdiaHost.quitCancelledHandler();
    assert(cancelled);
    NSEvent *key = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil characters:@"x" charactersIgnoringModifiers:@"x" isARepeat:NO keyCode:7];
    assert(!ArdiaPerformReservedKey(key));
    ArdiaChromeWindowHost.refusesUnhandledKeyHandler = ^BOOL(NSWindow *sender, NSEvent *event) { return YES; };
    key = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:window.windowNumber context:nil characters:@"x" charactersIgnoringModifiers:@"x" isARepeat:NO keyCode:7];
    assert(ArdiaPerformReservedKey(key));
    KeyTestView *input = [[KeyTestView alloc] initWithFrame:NSMakeRect(0,0,100,100)];
    window.contentView = input;
    NSTextField *message = [NSTextField labelWithString:@"Test modal message"];
    [input addSubview:message];
    assert([WebKitModalAlertText(window) isEqual:@"Test modal message"]);
    [message removeFromSuperview];
    assert(!WebKitPageAt(input, nil));
    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    WKWebView *page = [[WKWebView alloc] initWithFrame:NSMakeRect(0,0,10,10) configuration:configuration];
    NSView *child = [NSView new];
    [page addSubview:child];
    assert(WebKitPageAt(child, input) == page);
    assert(!WebKitPageAt(child, page));
    page.inspectable = YES;
    NSObject *inspector = [page valueForKey:@"_inspector"];
    for (NSString *selector in @[@"isVisible", @"isConnected", @"isElementSelectionActive", @"inspectorWebView", @"detach", @"close"]) {
      assert([inspector respondsToSelector:NSSelectorFromString(selector)]);
    }
    assert(![[inspector valueForKey:@"visible"] boolValue]);
    assert(![[inspector valueForKey:@"connected"] boolValue]);
    [page removeFromSuperview];
    assert([window makeFirstResponder:input]);
    [ArdiaChromeWindowHost devAction:@"key:e|14|0" window:window];
    assert(input.keys == 0);
    NSEvent *down = [NSApp nextEventMatchingMask:NSEventMaskKeyDown untilDate:[NSDate dateWithTimeIntervalSinceNow:1] inMode:NSDefaultRunLoopMode dequeue:YES];
    NSEvent *up = [NSApp nextEventMatchingMask:NSEventMaskKeyUp untilDate:[NSDate dateWithTimeIntervalSinceNow:1] inMode:NSDefaultRunLoopMode dequeue:YES];
    assert(down.window == window && up.window == window);
    assert([down.characters isEqual:@"e"] && down.keyCode == 14 && up.keyCode == 14);
    assert(window.firstResponder == input);
    NSMenu *menu = [NSMenu new];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Back" action:nil keyEquivalent:@"["];
    item.identifier = @"ardia.command.back";
    [menu addItem:item];
    NSApp.mainMenu = menu;
    assert([[ArdiaChromeWindowHost devAction:@"menus" window:window] containsString:@"ardia.command.back"]);
    assert([[ArdiaChromeWindowHost devAction:@"hardwareKey:33|1048576" window:window] isEqual:@"ok"]);
    down = [NSApp nextEventMatchingMask:NSEventMaskKeyDown untilDate:[NSDate dateWithTimeIntervalSinceNow:1] inMode:NSDefaultRunLoopMode dequeue:YES];
    up = [NSApp nextEventMatchingMask:NSEventMaskKeyUp untilDate:[NSDate dateWithTimeIntervalSinceNow:1] inMode:NSDefaultRunLoopMode dequeue:YES];
    assert(down.window == window && up.window == window && down.keyCode == 33 && up.keyCode == 33);
    assert(down.modifierFlags & NSEventModifierFlagCommand);
    for (NSString *action in @[@"hardwareKey:bad", @"key:bad", @"mouse:bad", @"resize:bad"]) {
      assert([[ArdiaChromeWindowHost devAction:action window:window] hasPrefix:@"invalid"]);
    }
    assert([[ArdiaChromeWindowHost devAction:@"state" window:window] containsString:@"lights"]);
    [window close];
    puts("PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard, queued literal/hardware keys, menu validation, inspector SPI");
  }
}
