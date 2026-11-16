# Step 4: site and browser settings

Native implementation verified; full UI completion remains blocked on Site Controls sound.

Baseline at `2e83cbbb7`: exit 0, 32 PASS, 4 `SKIPPED (no key window)`, 2 `NEEDS PERSON`. No source changed before that run.

## A. Results and scope limit

The eight automated rows cover native calls and page behavior. The final table below records their evidence and relaunches.

The Sound control in Site Controls still bypasses `setSiteSetting`. `apps/browser/src/state/site/siteControls.ts:50` calls `setSiteMuted` instead. `apps/browser/src/state/tabs/mute.ts:120` saves the host in the global `mutedSites` preference. It does not save a profile/origin decision in SQLite.

The native sound setting works through Settings and `sites.setSetting`. It persists per profile/origin and mutes page media after relaunch. Existing tab and site mute preferences can still mute the page independently.

The plan says: “Anything else in JS: stop and report.” Its native implementation rule permits platform-wrapper edits, not this state handler. No sound state handler changed. Step 4 remains partial until this exception is resolved.

The smallest follow-up changes `setSitePermission` in `state/site/siteControls.ts`: route WebKit sound decisions through `setSiteSetting`, clear a legacy site mute when allowing sound, and keep the existing Chromium branch. Add the corresponding handler test.

Location coverage stops at storage and the Settings response. No geolocation delegate integration was added. Stored location decisions do not control page geolocation requests. No geolocation request or macOS consent prompt ran. Camera and microphone tests invoke the real media-permission delegate with a local page frame, without starting capture.

The permission row also resolves an unanswered camera request with `permissions.resolve`, remembers the answer, and verifies it after another relaunch.

## Implementation

- `Store.mm` holds a bound-parameter settings table in each existing profile SQLite file. Private settings stay in memory.
- WebKit permissions and popup grants share that store. Legacy popup JSON migrates once; reset removes the migrated grant.
- Zoom restores on navigation and relaunch. Settings updates change live pages.
- Blocker setters change WebKit rule lists and host exemptions. Download preferences persist; existing download commands now have focused coverage.
- Profile deletion removes WebKit data and SQLite. Default-profile deletion bypasses obsolete Chromium cleanup. The last private window clears private settings.

Search selection already uses `packages/core/src/engines.ts`. Native `search.engines` lists extension-provided engines, not built-in choices. No duplicate engine list was added. The custom engine check supplies a fixture suggestion endpoint in memory to exercise the selected provider without internet requests.

About and the version page use the installed WebKit bundle version and app version. `engineInfo.chromiumVersion` remains a compatibility field containing the WebKit version. Displayed text says WebKit.

## Earlier placeholders

None of the five extension/bookmark placeholders from `upstream-endpoints.md` changed. They belong to Steps 5 and 8. Blocker state already had a real reader; its global, list, and host setters are now real.

No malformed stand-in answer required an out-of-scope default repair.

## Checks repaired during implementation

```text
native | FAIL | Undefined symbols: _WebKitProfileSettings, _WebKitSetProfileSetting, _WebKitDeleteProfileStore
```

The public C functions needed C linkage. The Swift self-check also needed the C++ runtime when linking Store.mm.

```text
Host.mm:55: error: use of undeclared identifier 'WebKitDeleteProfileStore'
```

The host needed the public settings declarations.

```text
native | FAIL | webkit-page.test.swift:43: Assertion failed
```

Private permission writes now establish the session they belong to. The self-check uses the production base-profile parser.

```text
about | FAIL | Timed out waiting for title Ardia WebKit Version
```

The navigation policy rejected the internal version URL. It now allows the generated version page.

No assertion or baseline was weakened.

## Plan and README gaps

- The plan treats search selection as missing native functionality. The existing JS core already implements built-in and custom selection.
- The plan does not account for Site Controls sound using a separate JS preference. Its JS restriction blocks completing that path.
- The README lacked the safe media-delegate test, resumable fixture, and background About/save-panel behavior. Those instructions are now included.

The README pod command succeeded: “Pod installation complete! There are 85 dependencies from the Podfile and 85 total pods installed.” No dependency or tracked Xcode project changed.

## Manual and unchecked paths

`needs-person.md` gained checks for the actual download picker, visible About panel, and location consent. Camera/microphone hardware capture remains unchecked. Existing key-window and trackpad limitations remain unchanged.

No real macOS consent dialog, internet provider request in a new row, owner profile, protected folder, or installed owner app was used. Search/favicon retain their existing network checks.

Site Controls sound UI is the remaining code blocker. The native API row does not prove that separate handler.

## B. Final full check

Exit code: **0**. 40 PASS, 4 `SKIPPED (no key window)`, 2 `NEEDS PERSON`.

| Row | Result | Evidence |
|---|---|---|
| zoom-site | PASS | zoom step persisted in SQLite; relaunch applied 1.1; other profile retained 1.5; Settings reset updated live page |
| site-settings | PASS | all five allow/block decisions survived two relaunches; profile isolation; Settings origins and reset; real media delegate grant/deny without capture; location storage only (system consent avoided) |
| clear-site-data | PASS | 127.0.0.1 cookies and localStorage cleared after reload; localhost cookies and localStorage retained |
| blocker-controls | PASS | global and EasyList toggles changed actual ad loads; per-host exemption survived relaunch; reset blocked again; Settings count > 0 |
| download-settings | PASS | folder and ask persisted across relaunch; background save-panel path logged; chosen folder used; slow local download paused/resumed to 8 MiB; second cancelled; actual picker needs a person |
| profiles | PASS | loaded/release reflect WebKit stores; profile deletion removed WebKit and SQLite; last private window cleared cookies and site settings; no private SQLite |
| search-engines | PASS | existing core list offers Google/DuckDuckGo/Bing/Kagi; custom choice survived relaunch and typed query loaded local URL; native suggestion transport used local fixture |
| about | PASS | engine.info and ardia://version show WebKit 22625.1.29.11.28, app 0.2.46; no Chromium wording |
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
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:53005/observe-js","http://127.0.0.1:53005/observe-native","http://127.0.0.1:53005/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 253 ms (<10000 ms) |
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


```text
Release build: /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/build-webkit.log
** BUILD SUCCEEDED **
app: /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/Build/Products/Release/Ardia WebKit.app
a1b767cf61a0829e09b21f52591af42aac9f5a0980c0f03371d6f9f774bf8243  /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/Ardia-WebKit-Release.zip
```

## Other observed issue

`WebKitDownloads.report` still sends `offTheRecord: false`, including for private profiles. This pre-existing event flag was not changed. Private-download persistence was not checked.

## Files and commit

Implementation: `cba6075df Implement native WebKit site and browser settings`.

```text
apps/browser/src/components/settings/panes/Advanced.tsx
docs/webkit/execution-plan.md
docs/webkit/needs-person.md
docs/webkit/standins.md
docs/webkit/step-4-results.md
docs/webkit/upstream-endpoints.md
packages/ardiacore/ios/ArdiaServices.h
packages/ardiacore/ios/PageEngine.swift
packages/ardiacore/ios/WebKitContentBlocker.swift
packages/ardiacore/ios/WebKitDownloads.swift
packages/ardiacore/ios/WebKitHub.swift
packages/ardiacore/ios/WebKitModule.swift
packages/ardiacore/ios/WebKitPermissions.swift
packages/ardiacore/ios/WebKitStores.swift
packages/ardiacore/ios/WebKitTab+PageTab.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/webkit/EngineBridge.mm
packages/ardiacore/ios/webkit/Host.mm
packages/ardiacore/ios/webkit/Services.mm
packages/ardiacore/ios/webkit/Standins.mm
packages/ardiacore/ios/webkit/Store.mm
packages/ardiacore/src/webkit.ts
packages/ardiacore/tests/webkit-data.test.mm
packages/ardiacore/tests/webkit-page-store.mm
packages/ardiacore/tests/webkit-page.test.swift
packages/ardiacore/tests/webkit-window.test.mm
packages/shell/ios/AppUpdater.swift
scripts/webkit/README.md
scripts/webkit/check.test.mjs
scripts/webkit/fixture.mjs
scripts/webkit/rows.mjs
scripts/webkit/settings-rows.mjs
```

The Progress row records the partial state. Nothing was pushed.
