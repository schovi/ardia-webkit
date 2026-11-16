# Step 3: page features

Must rows implemented. Inspector display and physical input remain unproven on this Mac. Should rows are deferred under Step 3's size limit.

## A. Results by row

| Row | Result | Evidence |
|---|---|---|
| inspector | NEEDS PERSON | `isInspectable=true`; Inspect and Developer Tools reach `_inspector` with supported selectors. Background mode logs requests instead of opening UI. |
| popup-blocked | PASS | Timer popup blocked; UI receives `id`, `url`, `origin`; Open Once loads it; Always Allow survives restart. |
| http-auth | PASS | Basic challenge logs the prompt; wrong input re-prompts; correct input loads; Cancel displays the server's 401 body. |
| load-error | PASS | Real refused loopback connection renders an error; injected DNS/offline delegate errors render; Retry loads a local fixture. URL/title stay correct. |
| page-colors | PASS, visual check pending | Dark space installs native backing `#251D1E`; `pageColor=plum`. A person must check transient flashes. |
| little-ardia | PASS | Native application URL callback opens a small window; Open in Ardia moves the same live DOM into the main window. |
| peek | Not done | Should row deferred. |
| tab-sleep | Not done | Should row deferred. |
| unresponsive | Not done | Should row deferred. Loop fixture exists but was not executed. |
| page-cookies | Not done | Should row deferred. |
| screen-share | Report only | No implementation or permission request. See public API limits below. |
| notifications | Report only | No implementation or permission request. See public API limits below. |

HTTP auth uses an AppKit sheet. No existing React page event handles HTTP challenges. The harness answers the same pending challenge in background mode. Credentials use `.none` persistence and never reach logs.

Popup grants use `<data>/WebKit/popup-grants.json`, keyed by profile and exact origin. Private grants stay in memory. Step 4 must connect these grants to site-settings controls and their SQLite storage.

Private API: `_setDeveloperExtrasEnabled:`, `_inspector`, `show`, `showConsole`, `toggleElementSelection`, and `WKNavigationAction._isUserInitiated`. The last property distinguishes script popups from user gestures. Unsupported inspector selectors produce no UI; missing gesture SPI blocks unsolicited popups conservatively.

Sources: WebKit's [_WKInspector](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKInspector.h), [_WKInspectorIBActions](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/_WKInspectorIBActions.h), and [WKNavigationActionPrivate](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKNavigationActionPrivate.h).

Local Inspector requires developer extras, separately from `isInspectable`. The command enables the preference and checks its value before showing or logging the request. [WebKit source](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/Inspector/WebInspectorUIProxy.cpp).

## Public API limits

The public [WKUIDelegate](https://developer.apple.com/documentation/WebKit/WKUIDelegate) exposes camera/microphone permission decisions. It exposes no display-capture permission callback or web-notification permission callback.

WebKit declares display-capture and notification permission callbacks in [WKUIDelegatePrivate.h](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKUIDelegatePrivate.h). A public embedder API for choosing or granting display capture is absent from these headers. This step does not prove `getDisplayMedia` with WebKit's picker.

Safari's [Web Push support](https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers) does not establish an equivalent public WKWebView integration. Native UserNotifications alone does not connect page subscriptions or permissions. Neither feature was built.

## B. Remaining stubs in WebKitTab+PageTab.swift

| Member | Reason |
|---|---|
| `temporary`, `temporarySource` | Peek Should row deferred. |
| `extensionHost` | Extension hosting belongs to Step 8. |
| `warm`, `neighbour` | Chromium prewarming hints; WebKit currently mounts regular pages. |
| `shownURL` | Chromium display hint; WebKit reports its own navigation URL. |
| `frozen` | Tab sleep Should row deferred. |
| `mediaCaptureSourceId` | No public display-capture source selection integration. |
| `pageCookies` | Should row deferred. |
| `resolvePasswordPrompt` | Passwords belong to Step 7. |
| `resolveAutofillPrompt` | Address/card autofill is not planned. |
| `executeExtensionAction` | Extension actions belong to Step 8. |
| `resolveDisplayMedia` | Screen sharing is report-only here. |
| `notificationAction` | Notifications are report-only. |
| `resolveUnresponsive` | Should row deferred. |
| `discard` | Tab sleep Should row deferred. |
| `takeControlPress` | Still returns true; Chromium's media-control activation handshake has no equivalent implementation here. |

`downloadImage` still delegates to favicon fetching and ignores `maxPixels`. Picture-in-Picture still ignores Chromium's `clickAt`/`control` hints. These pre-existing approximations are outside this step.

## Plan and README corrections

- Little Ardia does not send the `standalone` prop. `TabWebView` renders it inside a `small` window. Only extension views send `standalone`.
- The README's pod command fails at Podfile:110: `undefined method '[]' for nil` in `use_native_modules!`. No dependency repair was attempted. Existing source files avoid needing pod regeneration.
- The plan's old `errorPage` already rendered failures, but lacked Retry. This step retains that delegate path and adds Retry.

The first full check found two regressions:

```text
context-menu | FAIL | Timed out waiting for Cobalt Violet context-child
js | FAIL | size (1): new packages/ardiacore/ios/WebKitTab.swift
```

WebKit reported the native menu request as `type=-1 gesture=0 button=0`. The popup blocker rejected it. Native menu actions now grant one request for one second; the grant expires and clears after use. Native assertions cover expiry and reuse. The existing context-menu row verifies the original menu action and loaded tab.

The popup delegate moved into the existing UI delegate file. `WebKitTab.swift` stays below the 600-line convention limit. No assertion or baseline was weakened.

No stand-in default required repair. No unrelated product code changed.

Two interrupted check runs left hidden test apps, which recreated removed scratch directories. Ownership matched their scratch paths. Both apps were stopped and those directories removed. The harness interruption cleanup needs investigation; it was not changed.

## What remains unproven

Inspector display, physical DevTools shortcuts, auth sheet input, dark-tab flashes, and external delivery from another real application need a person. Harness delivery calls the native application URL callback directly.

DNS and offline failures use deterministic NSError injection into the real navigation delegate. The refused connection is real. The check never disables the Mac's network or depends on an external error host.

Peek gestures, sleep/reload, hung-page termination, cookie enumeration, screen sharing, and notifications were not checked. No screenshot proves transient page flashes.

Implementation commit: `f2fef5c3d` (`Implement WebKit page features and focused checks`).

## Files

```text
packages/ardiacore/ios/WebKitHub.swift
packages/ardiacore/ios/WebKitModule.swift
packages/ardiacore/ios/WebKitPageScript.swift
packages/ardiacore/ios/WebKitStores.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/WebKitTab+PageTab.swift
packages/ardiacore/ios/WebKitTab+UIDelegate.swift
packages/ardiacore/ios/WebKitWebView.swift
packages/ardiacore/tests/webkit-page.test.swift
scripts/webkit/page-rows.mjs
scripts/webkit/fixture.mjs
scripts/webkit/check.test.mjs
scripts/webkit/rows.mjs
docs/webkit/execution-plan.md
docs/webkit/needs-person.md
docs/webkit/standins.md
docs/webkit/step-3-results.md
```

## C. Full check

Exit code: **0**. 32 PASS, 4 SKIPPED (no key window), 2 NEEDS PERSON.

| Row | Result | Evidence |
|---|---|---|
| inspector | NEEDS PERSON | Inspect and Developer Tools command reached private _inspector; selectors present; inspectable=true; background mode suppressed UI; actual inspector and shortcut need a key window |
| popup-blocked | PASS | timer popup blocked; UI received id/url/origin; open once loaded Cobalt Violet automatic-child; Always allow survived relaunch |
| http-auth | PASS | Basic challenge logged; wrong credentials re-prompted; correct credentials loaded; Cancel displayed actual 401 body; sheet input needs a person |
| load-error | PASS | real refused loopback connection rendered error; injected DNS/offline errors used same delegate; Retry loaded local fixture; failed URL/title preserved |
| page-colors | PASS | native background=#251D1E; pageColor=plum; dark backing installed at attach; white flash needs visual check |
| little-ardia | PASS | native application URL delivery opened small window; Open in Ardia moved same live DOM to main window |
| type-page | SKIPPED (no key window) | this session cannot make the app active; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| type-omnibox | SKIPPED (no key window) | this session cannot make the app active; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| keys-page-focus | SKIPPED (no key window) | this session cannot make the app active; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| traffic-lights | PASS | explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=[[40,30],[63,30],[86,30]]; normal.png retained; visible layout needs a person |
| close-window | PASS | native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive |
| full-screen | SKIPPED (no key window) | this session cannot make the app active; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| user-sees | PASS | visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person |
| profile-switch | PASS | same window switched profile; work initially isolated, then work cookie; personal cookie survived return |
| swipe | NEEDS PERSON | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |
| context-menu | PASS | synthetic right-click link menu=Open Link,Open Link in New Tab,Download Linked File,Copy Link,,Share…,,Play All Animations,; open tab and copy link proven; page menu=Look Up “Link”,Translate “Link”,,Search with Google,,Copy,Copy Link with Highlight,,Share…,,,Show Writing Tools,Summarize,,Speech,,Play All Animations,; real mouse needs a person |
| settings-tour | PASS | 14 panes: general, profiles, sync, tabs, appearance, privacy, passwords, autofill, extensions, search, shortcuts, liveFolders, calendar, advanced; roots rendered; nonblank snapshots; no JS exceptions; /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/settings-tour-evidence |
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:51132/observe-js","http://127.0.0.1:51132/observe-native","http://127.0.0.1:51132/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 273 ms (<10000 ms) |
| smoke-h | PASS | same data dir restored 2 windows and all 3 tab URLs |
| smoke-i | PASS | personal cookie=personal; second profile initially empty, then cookie=work; first unchanged |
| smoke-j | PASS | two mounted pages with correct titles; widths=576,576 |
| smoke-k | PASS | bundled lists=2; control loaded; local ad blocked; blocked count=1; server received no ad request |
| favicon | PASS | Python icon=8218 characters; same PNG and UI icon after relaunch; snapshot=2720x1720 |
| history | PASS | 3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (4 visits); partial title found Cobalt Violet one |
| history-delete | PASS | deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0 |
| history-private | PASS | private page loaded; visits 3 -> 3; private native add=0; no extra store |
| search | PASS | weath -> 4 network suggestions (weather říčany); typed query loaded Google results |
| native | PASS | PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2258/2259 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |
Manual checklist: /Users/schovi/work/ardia-webkit/docs/webkit/needs-person.md

Release build output:

```text
Release build: /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/build-webkit.log
** BUILD SUCCEEDED **
app: /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/Build/Products/Release/Ardia WebKit.app
399474c2653dc35f072da17e7a927818aee131aea0291b74136d28fe00f07f28  /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/Ardia-WebKit-Release.zip
```
