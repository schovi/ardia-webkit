# Step 2: foreground follow-up

State: blocked. The session-lock check reports unlocked, but AppKit does not activate a key window through the permitted APIs.

## A. Step 2 results

The full `scripts/webkit/check` rebuilt Release and its zip. Exit code: 1. Results: 27 PASS, 4 FAIL, 1 NEEDS PERSON. All 22 baseline rows passed.

| Row | Result | Evidence |
|---|---|---|
| type-page | FAIL | Timed out: return ac.engine.call("windows.list").then(w=>w.some(w=>w.key));; last=false; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| type-omnibox | FAIL | Timed out: return ac.engine.call("windows.list").then(w=>w.some(w=>w.key));; last=false; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| keys-page-focus | FAIL | Timed out: return ac.engine.call("windows.list").then(w=>w.some(w=>w.key));; last=false; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| traffic-lights | PASS | explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=[[40,30],[63,30],[86,30]]; normal.png retained; visible layout needs a person |
| close-window | PASS | native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive |
| full-screen | FAIL | Timed out: return ac.engine.call("windows.list").then(w=>w.some(w=>w.key));; last=false; activation={"canBecomeKey":true,"active":false,"key":false,"policy":0} |
| user-sees | PASS | visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person |
| profile-switch | PASS | same window switched profile; work initially isolated, then work cookie; personal cookie survived return |
| swipe | NEEDS PERSON | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |
| context-menu | PASS | synthetic right-click link menu=Open Link,Open Link in New Tab,Download Linked File,Copy Link,,Share…,,Play All Animations,; open tab and copy link proven; page menu=Look Up “Link”,Translate “Link”,,Search with Google,,Copy,Copy Link with Highlight,,Share…,,,Show Writing Tools,Summarize,,Speech,,Play All Animations,; real mouse needs a person |
| settings-tour | PASS | 14 panes: general, profiles, sync, tabs, appearance, privacy, passwords, autofill, extensions, search, shortcuts, liveFolders, calendar, advanced; roots rendered; nonblank snapshots; no JS exceptions; /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/settings-tour-evidence |
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:63296/observe-js","http://127.0.0.1:63296/observe-native","http://127.0.0.1:63296/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 303 ms (<10000 ms) |
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
Manual checklist: /Users/schovi/work/ardia-webkit/docs/webkit/needs-person.md

## B. Findings and changes

| Row | Finding | Change or remaining limit |
|---|---|---|
| `type-page` | `open -n` did not yield an active/key window. A minimal AppKit app reproduced this without Ardia or React Native | `scripts/webkit/support.mjs:53` checks the session and uses foreground launch. `packages/ardiacore/ios/webkit/Host.mm:193` requests activation from a run-loop timer. The real-key guard still fails |
| `type-page` | The Chromium build excluded page clicks from React Native's touch recognizer; the WebKit build lacked that contract | `packages/ardiacore/ios/webkit/Host.mm:69` now excludes WebKit page presses and forwards `pagePress`. Native tests cover page-hit boundaries. Foreground typing remains unproven |
| `type-omnibox` | WebKit's `focus()` already calls `PageTab.focusPage`, not the Chromium stand-in. A direct probe changed native focus from false to true and counted one request | `packages/ardiacore/ios/WebKitTab+UIDelegate.swift:5` retains the real `makeFirstResponder` path. `packages/ardiacore/ios/WebKitModule.swift:32` exposes test-only focus evidence. Esc with a real key window remains unproven |
| `keys-page-focus` | Explicit back/forward commands navigated correctly after `live.canGoBack` became true. The inactive-window keyboard failure does not prove a navigation bug | The menu/reserved-key path remains the keyboard entry. No keyboard fix is claimed without a real key window |
| `full-screen` | Background mode intentionally disables element full screen. The foreground row now uses a native click and tests DOM/WebKit state, chrome state, Escape, and an in-process element capture | `scripts/webkit/window-rows.mjs:122` contains the real foreground check. Activation fails before the row can enter full screen |

The new in-app quit helper initially called `terminate:` from the main dispatch queue. A process sample showed AppKit waiting inside `_shouldTerminate`, which prevented the save reply on that queue. `packages/ardiacore/ios/WindowsModule.swift:15` now schedules quit on a run-loop timer. The quit smoke row passed without `osascript`; no cleanup needed a signal in the final run.

## Activation evidence

Ardia reported:

```json
{"canBecomeKey":true,"active":false,"key":false,"policy":0}
```

A separate AppKit-only application set regular activation policy and tried `activate()` and `activate(ignoringOtherApps: true)`. Both attempts reported:

```json
{"active":false,"key":false,"policy":0}
```

The control tried both `open -n <app>` and `open -n -a <app>`. It used no Ardia or React Native code. The exact reason for denied activation remains unknown. No fake active/key state replaced this evidence.

Control source, plist, and results remain in `apps/browser/build-webkit/step-2-evidence/activation-control.*`. Full output is `apps/browser/build-webkit/step-2-evidence/check-output.txt`. Direct focus/history results are `handler-probes.txt` in that directory.

## C. Check semantics

`NEEDS PERSON` applies only to the trackpad row. `SKIPPED (screen locked)` applies only to a locked foreground launch. Neither status counts as PASS or changes the exit code. FAIL and offline results still produce a nonzero exit. The command prints `docs/webkit/needs-person.md` for NEEDS PERSON or SKIPPED results.

Foreground launches keep scratch data/downloads, file keychain, and the harness probe. A lock file permits one foreground instance at a time. App-modal alerts get recorded, dismissed, and followed by quit; the row reports failure with their text. Eight harness self-checks passed, including modal failure after process exit. Native checks cover page-hit boundaries, modal text, and the background activation guard.

No check used `CGEventPost`, `osascript`, System Events, Accessibility APIs, or `screencapture`. Inputs and captures stay inside the app.

## D. Element full-screen snapshot

Not captured. The real-key guard failed before entry. The earlier simulated `fullscreen.png` was removed to avoid presenting it as real element full screen. `normal.png` remains the measured traffic-light capture.

## E. Remaining work

A real key window is the exact blocker. Page typing/Tab/copy/paste, Esc, page-focused history shortcuts, and element full screen remain unverified. The foreground mode does not turn these failures into NEEDS PERSON.

Run the checklist in `docs/webkit/needs-person.md` from the GUI session. First confirm that the scratch test window can become key through normal activation. Then rerun the foreground rows.

The earlier plan assumed that an unlocked session was sufficient for automatic activation. These runs did not support that assumption. The README now describes the real-key guard and in-app quit path. Steps 3 onward remain untouched. No push occurred.

## Files

```text
docs/webkit/execution-plan.md
docs/webkit/standins.md
packages/ardiacore/ios/WebKitModule.swift
packages/ardiacore/ios/WebKitTab+UIDelegate.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/WebKitWebView.swift
packages/ardiacore/ios/WindowsModule.swift
packages/ardiacore/ios/webkit/Host.mm
packages/ardiacore/tests/webkit-window.test.mm
scripts/webkit/README.md
scripts/webkit/check.mjs
scripts/webkit/check.test.mjs
scripts/webkit/report.mjs
scripts/webkit/rows.mjs
scripts/webkit/support.mjs
scripts/webkit/window-rows.mjs
docs/webkit/needs-person.md
docs/webkit/step-2-results.md
```
