#import "../ArdiaHost.h"
#import "../ArdiaWebView.h"
#import "../ArdiaTabStrip.h"
#import "../ArdiaEngineBridge.h"
#import "../ArdiaServices.h"
#import "../ArdiaContentBlocker.h"
#import "../ArdiaFavicons.h"
#import "../ArdiaSwipe.h"
#import "../ArdiaChromeWindowHost.h"

@implementation ArdiaHost
+ (BOOL )isStarted { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSDictionary<NSString *, id> *)engineInfo { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSArray<NSDictionary<NSString *, id> *> *)chromeWindows { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSArray<NSDictionary<NSString *, id> *> *)displayMediaSources { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL )screenRecordingAllowed { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)requestScreenRecording { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)resolveExternalApp:(NSString *)requestId open:(BOOL)open remember:(BOOL)remember { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)deviceChooser:(int)chooserId select:(int)index { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)deviceChooser:(int)chooserId action:(NSString *)action { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSArray<NSDictionary *> *)testExternalLaunches { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)devShowBluetoothChooser:(NSString *)tabId unauthorized:(BOOL)unauthorized { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSArray<NSDictionary *> *)testChooserEvents { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)shareTabInstead:(NSString *)capturerTabId target:(NSString *)targetTabId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)showCastDialog:(NSString *)tabId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)castDialog:(int)dialogId start:(NSString *)sink mode:(int)mode { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)castDialog:(int)dialogId stop:(NSString *)route { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)closeCastDialog:(int)dialogId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)watchCastRoutes:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)terminateCastRoute:(NSString *)route { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSDictionary<NSString *, id> *)actionStates:(NSString *)tabId extensions:(NSArray<NSString *> *)ids { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSString *)sidePanelURL:(NSString *)tabId extension:(NSString *)extensionId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)resolveExtensionInstallPrompt:(NSString *)requestId accepted:(BOOL)accepted { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)replayInstallPrompts { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)beginTracing:(void (^)(BOOL started))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)endTracing:(BOOL)keep completion:(void (^)(NSString *_Nullable path))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (BOOL )isTracing { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)deleteProfileData:(NSString *)profile completion:(void (^)(NSArray<NSString *> *remaining))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)releaseProfile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSArray<NSString *> *)loadedProfiles { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)stopCapture:(NSString *)tabId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)showAutofillSuggestions:(NSString *)tabId passwords:(BOOL)passwords { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (int)chromeTabIdOfTab:(NSString *)tabId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)cliTabTargets:(NSArray<NSString *> *)tabIds completion:(void (^)(NSDictionary<NSString *, id> *targets))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (BOOL)isPrivateProfile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void (^)(void))quitCancelledHandler { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setQuitCancelledHandler:(void (^)(void))value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (value) value(); }
+ (void)menuShortcutsChanged { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSString *)baseProfileOf:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)resolvePermission:(NSString *)requestId result:(NSString *)result remember:(BOOL)remember { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView
- (id<ArdiaWebViewDelegate> )delegate { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setDelegate:(id<ArdiaWebViewDelegate> )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setProfile:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)initialURL { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setInitialURL:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)adoptId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setAdoptId:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setTransferKey:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )standalone { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setStandalone:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )temporary { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setTemporary:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)temporarySource { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setTemporarySource:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)extensionHost { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setExtensionHost:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSColor *)pageBackgroundColor { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setPageBackgroundColor:(NSColor *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSColor *)contentsBackgroundColor { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setContentsBackgroundColor:(NSColor *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)pageColor { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setPageColor:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)shownURL { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setShownURL:(NSString *)value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )visible { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setVisible:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )warm { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setWarm:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )neighbour { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setNeighbour:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )autoPictureInPicture { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setAutoPictureInPicture:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (BOOL )discarded { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (BOOL )frozen { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)setFrozen:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (int )browserId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (NSString *)mediaCaptureSourceId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (NSView *)devtoolsView { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSArray<NSDictionary<NSString *, id> *> *)devEventsForBrowser:(int)browserId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSInteger)devWindowNumberForBrowser:(int)browserId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)devFocusPageOfBrowser:(int)browserId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSString *)devPagePhaseOf:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)devClosePageOf:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (int)browserIdOfTab:(nullable NSString *)tabId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL )reportsCommits { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setReportsCommits:(BOOL )value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (Transfer)
+ (void)prepareTransfer:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)releaseTransfer:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)startLaunchTab:(NSString *)transferKey url:(NSString *)url profile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)claimLaunchTab:(NSString *)transferKey url:(NSString *)url profile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)startLinkTabs:(NSArray<NSString *> *)urls profile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSDictionary<NSString *, id> *)routeLinkTabs:(NSArray<NSString *> *)urls { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)closeBrowser { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (Tab)
+ (void)setLittleArdiaOpensNewTabLinks:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)resolveUnresponsive:(BOOL)terminate { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (NSString *)discard:(BOOL)unload { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaWebView (Reveals)
+ (void)revealTab:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)dropTabReveals:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)revealOffered:(NSString *)adoptId over:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (BOOL)discardOffered:(NSString *)adoptId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaWebView (Focus)
+ (void)keepOutgoingFocusFrom:(NSResponder *)responder { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)endOutgoingFocusFrom:(NSResponder *)responder { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)focusPage { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (NeighbourPages)
+ (void)wakeNeighbourPagesIn:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)wakeNeighbourPagesIn:(NSWindow *)window seconds:(CFTimeInterval)seconds committed:(BOOL)committed { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)releaseNeighbourPagesIn:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (InputMonitors)
+ (void)installScrollZoom { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)installSwitchPrewarm { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setCommandScrollZoomEnabled:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSArray<NSNumber *> *)devScrollZoom:(NSArray<NSDictionary<NSString *, id> *> *)steps
                               browser:(int)browserId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaWebView (Recording)
- (void)copyRecordingPicture:(void (^)(CGImageRef _Nullable picture))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (BOOL )recordingShowsPage { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSArray<NSWindow *> *)recordingPictureInPictureWindowsOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)recordingWindowIsPrivate:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (CGFloat)recordingCornerRadiusOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSView *)recordingControlsOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)copyRecordingPictureOfWindow:(NSWindow *)window
                          completion:(void (^)(CGImageRef _Nullable picture))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
@end

@implementation ArdiaWebView (PageMessages)
+ (void)setDisplayMediaPicker:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setSelectionPopoverEnabled:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)resolveDisplayMedia:(NSString *)requestId sourceId:(nullable NSString *)sourceId audio:(BOOL)audio { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (Peek)
+ (void)setPeekModifier:(NSString *)modifier { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setSplitLinkModifier:(NSString *)modifier { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setPeekOtherSiteTabs:(NSArray<NSString *> *)tabIds { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (BOOL)devPostPeekMouseUp:(NSString *)keys over:(NSString *)transferKey { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaWebView (ContextMenu)
+ (void)setSearchEngineName:(NSString *)name { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)removeSharedImage:(NSURL *)file { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)removeSharedImages { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (PictureInPicture)
+ (void)setAutoPictureInPictureEnabled:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setVideoUpscalingEnabled:(BOOL)enabled { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setVideoUpscalingTestConditions:(NSDictionary<NSString *, NSNumber *> *)conditions { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSDictionary<NSString *, id> *)videoUpscalingState { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (BOOL)takeControlPressAt:(double)clickMs control:(NSInteger)target { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)requestPictureInPictureForClickAt:(double)clickMs
                                  control:(NSInteger)target
                               completion:(void (^)(BOOL ok))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)exitPictureInPicture { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (PictureInPictureDev)
+ (NSArray<NSDictionary<NSString *, id> *> *)devPictureInPicture { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (NSString *)devPictureInPictureAction:(NSString *)action { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaWebView (Navigation)
- (void)loadURL:(NSString *)url userInitiated:(BOOL)userInitiated { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)goBack { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)goForward { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)goToHistoryOffset:(NSInteger)offset { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)reload { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)reloadIgnoringCache { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)stopLoading { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)openBlockedPopup:(NSString *)popupId always:(BOOL)always { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (PageCommands)
- (void)setMuted:(BOOL)muted { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)setZoomFactor:(double)factor { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)zoomStep:(NSInteger)direction { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)find:(NSString *)text forward:(BOOL)forward findNext:(BOOL)findNext { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)stopFinding:(BOOL)clearSelection { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)print { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)showDevTools { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)showDevToolsPanel:(nullable NSString *)panel { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)runPageCommand:(NSString *)name { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)executeJavaScript:(NSString *)code { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)evaluate:(NSString *)code completion:(void (^)(NSString *_Nullable json))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)capturePicture:(double)scale completion:(void (^)(NSDictionary<NSString *, id> *_Nullable picture))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)navigationEntries:(void (^)(NSArray<NSDictionary<NSString *, id> *> *entries))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)downloadFavicon:(NSString *)url name:(nullable NSString *)name
             completion:(void (^)(NSDictionary<NSString *, id> *_Nullable result))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)downloadImage:(NSString *)url
            maxPixels:(NSInteger)maxPixels
           completion:(void (^)(NSDictionary<NSString *, id> *_Nullable result))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)mediaCommand:(NSString *)action seconds:(double)seconds { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaWebView (Site)
- (void)securityInfo:(void (^)(NSDictionary<NSString *, id> *info))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)pageCookies:(NSArray<NSString *> *)urls
         completion:(void (^)(NSArray<NSDictionary<NSString *, id> *> *_Nullable cookies))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
- (void)clearSiteData:(void (^)(id _Nullable result, NSString *_Nullable error))reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
- (void)resolvePasswordPrompt:(NSString *)action username:(nullable NSString *)username password:(nullable NSString *)password { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (void)resolveAutofillPrompt:(NSInteger)promptId action:(NSString *)action { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
- (nullable NSString *)executeExtensionAction:(NSString *)extensionId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
- (void)notificationAction:(NSString *)notificationId action:(NSString *)action { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaTabStrip
+ (void)watchStrips { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (NSDictionary<NSString *, id> *)allStrips { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)command:(NSInteger)commandId command:(NSDictionary<NSString *, id> *)command { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaEngineBridge
+ (void)callWithSecret:(NSString *)name
               profile:(NSString *)profile
                  args:(NSMutableData *)args
            completion:(void (^)(NSString *json))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)callForSecretReply:(NSString *)name
                   profile:(NSString *)profile
                   timeout:(NSTimeInterval)timeout
                completion:(void (^)(NSDictionary<NSString *, id> *_Nullable reply))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)forwardEngineEvents { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)observe:(NSString *)topic handler:(void (^)(NSDictionary<NSString *, id> *payload))handler { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (handler) handler({}); }
@end

@implementation ArdiaServices
+ (void)call:(NSString *)name
       profile:(NSString *)profile
          args:(nullable NSDictionary<NSString *, id> *)args
    completion:(ArdiaCoreResult)completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)listPasswords:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)unlockPasswords:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)password:(NSString *)profile origin:(NSString *)origin username:(NSString *)username reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)savePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username password:(NSString *)password
               reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)updatePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username
           newUsername:(nullable NSString *)newUsername newPassword:(nullable NSString *)newPassword reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)deletePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)neverSaveOrigins:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)allowSaving:(NSString *)profile origin:(NSString *)origin reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)exportPasswords:(NSString *)profile path:(nullable NSString *)path reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (BOOL)profileToggle:(ArdiaProfileToggle)toggle profile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setProfileToggle:(ArdiaProfileToggle)toggle value:(BOOL)value profile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)addresses:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)saveAddress:(NSDictionary<NSString *, id> *)address profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)cards:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)saveCard:(NSDictionary<NSString *, id> *)card number:(nullable NSString *)number profile:(NSString *)profile
           reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)deleteAutofillEntry:(NSString *)entryId profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)revealCardNumber:(NSString *)cardId profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)zoomLevels:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)setZoom:(double)zoom profile:(NSString *)profile host:(NSString *)host { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)listExtensions:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (NSDictionary<NSString *, id> *)inspectUnpacked:(NSString *)path { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)installExtension:(NSString *)path profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)installCrx:(NSString *)path profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)setExtension:(NSString *)extensionId enabled:(BOOL)enabled profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)uninstallExtension:(NSString *)extensionId profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)reloadExtension:(NSString *)extensionId profile:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)configureExtension:(NSString *)extensionId profile:(NSString *)profile options:(NSDictionary<NSString *, id> *)options
                     reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)searchEngineList:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)watchDownloadEvents { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)watchDownloads:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)downloadCommand:(NSString *)command id:(NSString *)downloadId { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)siteSettings:(NSString *)profile origin:(NSString *)origin reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)setSiteSetting:(NSString *)value profile:(NSString *)profile origin:(NSString *)origin type:(NSString *)type { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)siteSettingsOrigins:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)resetSiteSettings:(NSString *)profile origin:(NSString *)origin { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)clearSiteData:(NSString *)profile origin:(NSString *)origin reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)externalAppAllowances:(NSString *)profile reply:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)removeExternalAppAllowance:(NSString *)profile origin:(NSString *)origin scheme:(NSString *)scheme { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)tasks:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)components:(ArdiaServiceReply)reply { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (reply) reply({}, {}); }
+ (void)clearBrowsingData:(NSString *)profile types:(NSArray<NSString *> *)types since:(double)sinceMs completion:(void (^)(void))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion(); }
@end

@implementation ArdiaContentBlocker
+ (void)state:(void (^)(NSDictionary<NSString *, id> *state))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)setEnabled:(BOOL)enabled completion:(void (^)(NSString *_Nullable error))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)setList:(NSString *)listId enabled:(BOOL)enabled completion:(void (^)(NSString *_Nullable error))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)isAllowedOnHost:(NSString *)host completion:(void (^)(BOOL allowed))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)setAllowed:(BOOL)allowed onHost:(NSString *)host completion:(void (^)(NSString *_Nullable error))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
+ (void)devFailNextMessage { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)devDelayNextLoad:(double)ms { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaFavicons
+ (void)fetch:(NSString *)url
       profile:(NSString *)profile
          name:(nullable NSString *)name
    completion:(void (^)(NSDictionary<NSString *, id> *_Nullable result))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
@end

@implementation ArdiaSwipe
+ (void)performHaptic:(NSString *)pattern { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)addTarget:(NSView<ArdiaSwipeTarget> *)target { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)removeTarget:(NSView<ArdiaSwipeTarget> *)target { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
@end

@implementation ArdiaSwipe (Simulation)
+ (void)simulateInWindow:(NSWindow *)window
                   point:(NSPoint)point
                   steps:(NSArray<NSDictionary<NSString *, id> *> *)steps
  ignoreSystemPreference:(BOOL)ignoreSystemPreference
              completion:(void (^)(NSDictionary<NSString *, id> *result))completion { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (completion) completion({}); }
@end

@implementation ArdiaChromeWindowHost
+ (CGFloat )windowCornerRadius { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSWindow *)makeWindowForProfile:(NSString *)profile { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSWindow *)makeWindowForProfile:(NSString *)profile chromeWindow:(nullable NSString *)chromeWindow { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSWindow *)makeWindowForProfile:(NSString *)profile
                               chromeWindow:(nullable NSString *)chromeWindow
                                  appWindow:(nullable NSString *)appWindow { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)recordLaunchLayout { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)forgetLaunchPictures { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (BOOL)takeDismissedAppWindow:(NSString *)appWindow { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)embedRootView:(NSView *)root inWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (nullable NSView *)rootViewOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (nullable NSView *)embeddedRootOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (Class )contentViewClass { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)removeRootViewOfWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)setTrafficLightsCenter:(nullable NSValue *)center trailing:(BOOL)trailing inWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)moveTrafficLightsCenter:(nullable NSValue *)center trailing:(BOOL)trailing inWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)closeWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)showProfile:(NSString *)profile inWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void)prepareProfiles:(NSArray<NSString *> *)profiles forWindow:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (void (^)(NSWindow *from, NSWindow *to))swappedHandler { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setSwappedHandler:(void (^)(NSWindow *from, NSWindow *to))value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); if (value) value({}, {}); }
+ (BOOL (^)(NSWindow *window))shouldCloseHandler { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setShouldCloseHandler:(BOOL (^)(NSWindow *window))value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (BOOL (^)(NSWindow *window, NSEvent *event))refusesUnhandledKeyHandler { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (void)setRefusesUnhandledKeyHandler:(BOOL (^)(NSWindow *window, NSEvent *event))value { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); }
+ (BOOL)windowShouldClose:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)windowFullScreenIsForPage:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
+ (BOOL)userSeesWindow:(nullable NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaChromeWindowHost (Dev)
+ (nullable NSString *)devAction:(NSString *)action window:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end

@implementation ArdiaChromeWindowHost (DevFullScreenProbe)
+ (NSString *)devFullScreenProbe:(nullable NSString *)argument window:(NSWindow *)window { static dispatch_once_t once; dispatch_once(&once, ^{ NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }); return {}; }
@end
