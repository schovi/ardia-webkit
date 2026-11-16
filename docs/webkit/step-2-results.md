# Step 2: foreground verification

Done. `scripts/webkit/check` rebuilt Release and its zip, then exited 0.

74 PASS, 2 SKIPPED (no source profile), 1 NEEDS PERSON.

## Causes and fixes

| Row | Cause | Fix |
|---|---|---|
| `type-omnibox` | The old helper called `keyDown` directly. React Native's Esc command gate requires `NSApp.currentEvent` (`patches/react-native-macos@0.81.9.patch:256`), so the UI never requested page focus. The failed probe reported `focusRequests=1`, responder `BrowserWindow`. | `packages/ardiacore/ios/webkit/Host.mm:278` posts down/up events to the app queue. Esc now calls the existing `WebKitTab.focusPage` path, with `focusRequests=2` and responder `WebKitWebView`. |
| `keys-page-focus` | Back and Forward use AppKit menu key equivalents. The enabled Back item expected `ú` on this Mac's Czech layout. The helper sent literal `[`, which reached the DOM. Forward expected `)`. | `packages/ardiacore/ios/webkit/Host.mm:257` constructs local hardware events using the existing `SyntheticInput.hardwareKey` recipe. `scripts/webkit/window-rows.mjs:17` uses them for shortcuts. The row asserts page focus and Back menu validation. |
| `full-screen` | `packages/shell/ios/WindowManager.swift:432` publishes JS full-screen state at `willEnter` / `willExit`. The row advanced before AppKit completed the transition. Native traces showed `willExit` with `seen=false`, followed by `didExit`. | `scripts/webkit/window-rows.mjs:32` waits for the completed notification, visible occlusion state, and an active/key page window. The timeout stays unchanged. Entry still requires a trusted native click; failures report request status. |

Before edits: Esc failed 3/3; history shortcuts failed 3/3; full screen failed 1/3.
No browser JS changed. The bridge already calls `PageTab.focusPage`; this checkout has no `focusIfUnfocused` method.

## Three consecutive runs

Each row ran three independent `scripts/webkit/check --no-build --only <row>` calls. The loop exited 0.

| Row | Result | Evidence |
|---|---|---|
| type-omnibox | PASS | queued Cmd+L; native URL typing and Return loaded fixture; Esc restored WebKitWebView; focusRequests=2; active/key window, in-app input |
| type-omnibox | PASS | queued Cmd+L; native URL typing and Return loaded fixture; Esc restored WebKitWebView; focusRequests=2; active/key window, in-app input |
| type-omnibox | PASS | queued Cmd+L; native URL typing and Return loaded fixture; Esc restored WebKitWebView; focusRequests=2; active/key window, in-app input |
| keys-page-focus | PASS | queued native Cmd+T/W/R/F and physical bracket keys changed tabs, reload, find and history; page focus asserted; Back menu key=ú; plain x reached DOM |
| keys-page-focus | PASS | queued native Cmd+T/W/R/F and physical bracket keys changed tabs, reload, find and history; page focus asserted; Back menu key=ú; plain x reached DOM |
| keys-page-focus | PASS | queued native Cmd+T/W/R/F and physical bracket keys changed tabs, reload, find and history; page focus asserted; Back menu key=ú; plain x reached DOM |
| full-screen | PASS | real window full screen reached didEnter/didExit; native click entered DOM element full screen; WebKit state=2 and chrome hidden; Esc restored element/chrome; element-fullscreen.jpg retained |
| full-screen | PASS | real window full screen reached didEnter/didExit; native click entered DOM element full screen; WebKit state=2 and chrome hidden; Esc restored element/chrome; element-fullscreen.jpg retained |
| full-screen | PASS | real window full screen reached didEnter/didExit; native click entered DOM element full screen; WebKit state=2 and chrome hidden; Esc restored element/chrome; element-fullscreen.jpg retained |

## Step 2 and Inspector results

| Row | Result | Evidence |
|---|---|---|
| inspector | PASS | Inspect opened a visible frontend with element selection active; detached native window=72948, 1000x650; closed; queued Option+Command+I reopened visible window=72949; inspector.png retained |
| type-page | PASS | synthetic click, native keys: hello; Tab to second; Cmd+C/V copied hello; active/key window, in-app input |
| type-omnibox | PASS | queued Cmd+L; native URL typing and Return loaded fixture; Esc restored WebKitWebView; focusRequests=2; active/key window, in-app input |
| keys-page-focus | PASS | queued native Cmd+T/W/R/F and physical bracket keys changed tabs, reload, find and history; page focus asserted; Back menu key=ú; plain x reached DOM |
| traffic-lights | PASS | explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=[[40,30],[63,30],[86,30]]; normal.png retained; visible layout needs a person |
| close-window | PASS | native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive |
| full-screen | PASS | real window full screen reached didEnter/didExit; native click entered DOM element full screen; WebKit state=2 and chrome hidden; Esc restored element/chrome; element-fullscreen.jpg retained |
| user-sees | PASS | visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person |
| profile-switch | PASS | same window switched profile; work initially isolated, then work cookie; personal cookie survived return |
| swipe | NEEDS PERSON | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |
| context-menu | PASS | synthetic right-click link menu=Open Link,Open Link in New Tab,Download Linked File,Copy Link,,Share…,,Play All Animations,,; open tab and copy link proven; page menu=Look Up “Link”,Translate “Link”,,Search with Google,,Copy,Copy Link with Highlight,,Share…,,,Show Writing Tools,Summarize,,Speech,,Play All Animations,,; real mouse needs a person |

The Inspector row checks private `_inspector` state and its actual `inspectorWebView`. It requires a loaded frontend in a visible native window. It proves selection mode, detaches the window, closes it, and reopens it through queued Option+Command+I. The retained capture shows the fixture DOM in Web Inspector.

Native self-checks cover queued literal keys, hardware key codes/modifiers/window ownership, invalid input, menu validation, and the Inspector SPI contract. JS tests: 2261/2262 passed; only the allowed expired-watch fixture failed. Typecheck passed.

## Captures and logs

Artifacts stay under `/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-2-evidence/`:

- `normal.png`, `fullscreen.png`, `element-fullscreen.jpg`, `inspector.png`.
- `before.txt`, `keyboard-layout.txt`, `fullscreen-before.txt`, `three-passes.txt`, `inspector-output.txt`, `fullscreen.log`, `check-output.txt`.

`fullscreen.log` records real AppKit callbacks and WebKit states `1 -> 2 -> 3 -> 0`. The element capture came from the real full-screen `WKWebView`; chrome state was checked separately.

## Limits and documentation corrections

The README lacked the `NSApp.currentEvent` requirement, keyboard-layout handling, and the distinction between `will` and `did` full-screen notifications. It also called denied activation a failure, although the harness reports a skip. These descriptions now match the checks.

Foreground automation posts events inside Ardia. Physical keyboard delivery through WindowServer and real trackpad gestures remain unproven. `swipe` stays `NEEDS PERSON`. The two missing local import sources remain skips, outside Step 2.

The shorter [manual checklist](needs-person.md) retains other steps' sheet, picker, hardware, password, and extension checks. No real Keychain, Touch ID, protected-folder access, hardware capture, or system input injection ran. Probe scratch directories, fixture servers, and app instances were stopped or removed. No push occurred.
