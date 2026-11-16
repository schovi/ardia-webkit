# Step 2: window and keyboard

State: blocked on hidden input and foreground verification. The unchanged baseline passed all 22 rows before edits.

## A. Check results

`scripts/webkit/check` rebuilt Release and its zip. Exit code: 1. Results: 27 PASS, 5 FAIL. All 22 earlier rows still passed.

| Row | Result | Evidence |
|---|---|---|
| type-page | FAIL | native key dispatch did not type into WebKit; responder=Ardia_WebKit.BrowserWindow; needs a person; '' !== 'hello';  |
| type-omnibox | FAIL | The input did not match the regular expression /WK/. Input:; 'Ardia_WebKit.BrowserWindow';  |
| keys-page-focus | FAIL | Timed out: const t=ac.store.getState().tabs["tab-mwj8tkigfdd9-2"];return t&&ac.webviews.has(t.id)&&t.title==="Cobalt Violet keyboard";; last=false |
| traffic-lights | PASS | explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=[[40,30],[63,30],[86,30]]; normal.png retained; visible layout needs a person |
| close-window | PASS | native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive |
| full-screen | FAIL | window full screen enter/exit notifications and snapshot proven in hidden simulation; WebKit disables element full screen in background mode; native element transition and chrome hiding need a person |
| user-sees | PASS | visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person |
| profile-switch | PASS | same window switched profile; work initially isolated, then work cookie; personal cookie survived return |
| swipe | FAIL | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |
| context-menu | PASS | synthetic right-click link menu=Open Link,Open Link in New Tab,Download Linked File,Copy Link,,Share…,,Play All Animations,; open tab and copy link proven; page menu=Look Up “Link”,Translate “Link”,,Search with Google,,Copy,Copy Link with Highlight,,Share…,,,Show Writing Tools,Summarize,,Speech,,Play All Animations,; real mouse needs a person |
| settings-tour | PASS | 14 panes: general, profiles, sync, tabs, appearance, privacy, passwords, autofill, extensions, search, shortcuts, liveFolders, calendar, advanced; roots rendered; nonblank snapshots; no JS exceptions; /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/settings-tour-evidence |
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:62318/observe-js","http://127.0.0.1:62318/observe-native","http://127.0.0.1:62318/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 162 ms (<10000 ms) |
| smoke-h | PASS | same data dir restored 2 windows and all 3 tab URLs |
| smoke-i | PASS | personal cookie=personal; second profile initially empty, then cookie=work; first unchanged |
| smoke-j | PASS | two mounted pages with correct titles; widths=576,576 |
| smoke-k | PASS | bundled lists=2; control loaded; local ad blocked; blocked count=1; server received no ad request |
| favicon | PASS | Python icon=8218 characters; same PNG and UI icon after relaunch; snapshot=2720x1720 |
| history | PASS | 3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (4 visits); partial title found Cobalt Violet one |
| history-delete | PASS | deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0 |
| history-private | PASS | private page loaded; visits 3 -> 3; private native add=0; no extra store |
| search | PASS | weath -> 4 network suggestions (weather říčany); typed query loaded Google results |
| native | PASS | PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard |
| js | PASS | 2258/2259 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |

The final source rebuild passed after moving the full-screen observer into the existing UI delegate file. Deep signature verification passed. The focused full-screen row on that binary repeated the same documented blocker, with exit code 1.

Release zip: `apps/browser/build-webkit/Ardia-WebKit-Release.zip`. SHA-256: `7a41b77abfe1ca5e406cd37ec47aa10960c01a215e16e714348c19f02d3c2589`.

## B. In-process snapshots

- Normal window with explicitly requested traffic-light centers: `/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-2-evidence/normal.png`.
- Simulated window full screen: `/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-2-evidence/fullscreen.png`.
- Raw build/check output: `/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-2-evidence/check-output.txt`.

The normal capture draws AppKit traffic buttons separately from the window's layers. Hidden windows show inactive buttons. The full-screen capture proves a frame change and notifications, not a real Space or element full screen.

## C. Native contracts

| Owner | Implemented |
|---|---|
| `ArdiaChromeWindowHost` | Traffic-light set/move and getters; corner radius; root/embedded-root lookup and removal; close; close-policy and refused-key callbacks; visibility; page-full-screen flag |
| `ArdiaHost` | Store the quit-cancelled callback instead of calling it during registration |
| `ArdiaPerformReservedKey` | Query the current menu for Command/Control shortcuts and honor the refused-key callback |
| `BrowserWindow` | Lay out requested traffic-light centers, including trailing placement; route close through policy; simulate full screen only in background mode |
| `WebKitWebView` / `WebKitTab` | Log and select real native context-menu actions; cancel hidden menu tracking; observe WebKit full-screen state and emit the existing page event |

| Retained call | Reason |
|---|---|
| `ArdiaChromeWindowHost.showProfile`, `prepareProfiles` | React Native mounts profile-specific WebKit views. The same-window cookie row proves that path without Chromium window swapping |
| Chromium window construction, embedding, swapping, launch pictures | The app constructs a plain `BrowserWindow` and sets its content controller directly |
| `ArdiaWebView.focusPage` | Chromium-only host. `PageViewDefinition` calls the existing `WebKitTab.focusPage` for WebKit tabs |
| `ArdiaSwipe` | WebKit already enables `allowsBackForwardNavigationGestures`. Chromium's custom gesture machinery stays unused |
| `ArdiaHost.menuShortcutsChanged` | Intentional no-op: native key routing reads the current menu for each shortcut; no engine shortcut cache exists |

`userSeesWindow` previously returned false. `WebKitTab+AutoPictureInPicture.swift` uses it to decide automatic Picture in Picture. Visible hidden-test windows now establish a seen baseline. Foreground windows use AppKit visibility, minimization, and occlusion. Window visibility notifications trigger reconsideration.

No stand-in result needed a shaped-default exception on these paths. The generator now discovers the single-line hand-written methods added here and excludes their stand-ins.

## Needs a person at the screen

1. Click page fields, type, use Tab, copy/paste, and verify Esc returns from the command bar to page input.
2. Exercise all listed shortcuts with page focus. Synthetic Cmd+T/W/R/F passed their assertions; Cmd+[ did not navigate. Cmd+] and plain page keys remain unchecked after that failure.
3. Enter a real full-screen Space. Enter and exit video/element full screen and confirm that browser chrome hides and returns.
4. Check traffic-light layout, resizing, sidebar toggles, minimize/zoom, and visibility behind other windows.
5. Swipe with a trackpad and exercise native context menus with a real mouse.

Synthetic Cmd+L, URL typing, and Return loaded the fixture. Esc left `BrowserWindow` as first responder. Synthetic page clicks also left that responder, and the field stayed empty. These results do not prove the foreground path.

## Plan and README corrections

The requested `WebKitPagePresses.swift` and `WebKitTab+PageInput.swift` files do not exist. Their relevant code lives in `WebKitWebView.swift` and `WebKitTab.swift`.

The generator previously had an explicit exclusion list, not general implementation discovery. The Release dev hook originally supported snapshots only. The new event hooks use `windows.dev`, since Release lacks `ArdiaDev` functions.

Upstream's hidden-input description includes a richer fake-active/key-window model. This fork originally suppressed `makeKeyWindow` completely. The new internal key-window reference never takes system focus, but hidden page input remains blocked.

The original layer snapshot omitted AppKit traffic buttons. Frame snapshots now cache those buttons separately.

## Not checked

No foreground window, real Space transition, trackpad recognition, foreground occlusion, or alternative keyboard layout was checked. The failed page-input row never reached Tab or copy/paste assertions. Steps 3 onward remain untouched. No push or release occurred.

## Files

```text
apps/browser/macos/Ardia-macOS/BrowserWindow.swift
docs/webkit/standins.md
docs/webkit/step-2-results.md
packages/ardiacore/ios/ArdiaChromeWindowHost.h
packages/ardiacore/ios/WebKitTab+UIDelegate.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/WebKitWebView.swift
packages/ardiacore/ios/webkit/Host.mm
packages/ardiacore/ios/webkit/Standins.mm
packages/ardiacore/scripts/generate-webkit-standins.py
packages/ardiacore/tests/webkit-window.test.mm
scripts/webkit/README.md
scripts/webkit/rows.mjs
scripts/webkit/window-rows.mjs
docs/webkit/execution-plan.md
```
