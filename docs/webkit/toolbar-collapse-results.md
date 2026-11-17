# Toolbar collapse investigation

The reported 17–21 pt screen strip remains **unreproduced**. The owner’s macOS and WebKit versions remain unknown. No result here establishes an OS defect.

This Mac runs macOS 27.0.1, build 26A434, WebKit 22625.1.29.11.28, at backing scale 2. System Reduce Motion is on. Tests force the app's motion flag both off and on without changing system settings.

## Reproduction gaps checked

Every native case uses a real key window, a scratch profile, and app-local input. Each instance quits after its cases.

| Case | Observed result |
|---|---|
| Original DOM wheel plus `scrollBy`, Release and Debug/Metro | Collapsed viewport 1161×822; scrollY 360; full in-process image |
| Native gesture and momentum phases, motion off/on, Release and Debug/Metro | 34 events hit WebKit; began/changed/ended recorded for each phase family; scrollY 960; full geometry and cache |
| Same native gesture with Inspector already docked, both motion flags and builds | Page 1161×322 plus 500 pt Inspector; no strip |
| Page starts at scrollY 400, both flags and builds | ScrollY 1360 after collapse; full 1161×822 viewport |
| Page still loading, both flags and builds | `readyState="interactive"`, resource pending; collapse reaches 1161×822 and scrollY 960 |

A smaller Release gesture reaches `[1161,822,64,1]`, close to the reported scrollY 58. It also preserves a full page with Inspector docked. A live `idnes.cz` Release run reaches `[1161,822,960,1]` with full geometry and AppKit images. Its page consent and Google sign-in overlays remain untouched. Evidence: `after-small-native-*.json/png` and `idnes*.json/png`.

Debug uses `/private/tmp/ardia-toolbar-debug/Build/Products/Debug/Ardia WebKit.app` against an owned Metro server on port 8099. Release uses the bundled JS. Diagnostic instrumentation exists in both builds. Debug/Metro also passes the complete toolbar row, before the later type/import/file-placement repairs. Its split-pane check reads `["collapsed","collapsed"]`; dumps and a snapshot sit in `toolbar-evidence/debug-final/`. Native queue delivery proves routing, not physical trackpad or WindowServer behavior. Momentum events reach WebKit; this does not prove hardware-equivalent kinetic scrolling.

Evidence stays in `apps/browser/build-webkit/toolbar-evidence/`: `native-*.json/png`, `debug-native-*.json/png`, `release-scrolled-*.json/png`, `debug-scrolled-*.json/png`, `release-loading-*.json/png`, and `debug-loading-*.json/png`. Probe logs sit beside them.

## Geometry before any fix

`native-false-false.json` records the ordinary page:

```text
at=0.0  WebKitWebView frame={{0,0},{1161,801}} visibleRect={{-190,-50},{1360,860}}
at=0.1  WebKitWebView frame={{0,0},{1161,822}} visibleRect={{-190,-29},{1360,860}}
at=0.4  WebKitWebView frame={{0,0},{1161,822}} visibleRect={{-190,-29},{1360,860}}
at=2.0  WebKitWebView frame={{0,0},{1161,822}} visibleRect={{-190,-29},{1360,860}}
```

No ancestor limits the page to 21 pt. The native-driver transform appears during the motion-off case, then settles. `WKFlippedView` grows with its web view. Recorded attachments show no temporary removal from the window. `_clipsToVisibleRect` reports false, and `documentVisibleRect` retains the full viewport dimensions. This framework exposes neither `_exposedContentRect` nor `_drawingAreaSize` through the guarded getters.

`visibleRect` exceeds `bounds` even before collapse. The row therefore checks containment, ancestor clipping bounds, and absent layer masks. Literal equality would fail the healthy baseline.

## Proven neighboring defect and fix

`packages/ardiacore/ios/WebKitTab.swift:58` at `3e51a4465` forced flipped coordinates. WebKit docks its Inspector using non-flipped parent coordinates. This put the Inspector above the page.

Before, from `inspector-before.json`:

```text
WebKitTab           flipped=true  bounds={{0,0},{1161,822}}
WebKitWebView        frame={{0,500},{1161,322}}
WKInspectorWKWebView frame={{0,0},{1161,500}}
```

`packages/ardiacore/ios/WebKitTab.swift:8` now inherits AppKit's non-flipped coordinates. The docked page and Inspector fill their parent with the Inspector below.

After, from `after-small-native-false-true-owner.json`:

```text
WebKitTab           flipped=false bounds={{0,0},{1161,822}}
WebKitWebView        frame={{0,500},{1161,322}}
WKInspectorWKWebView frame={{0,0},{1161,500}}
```

The coordinates stay the same; their parent now interprets y=0 as the bottom. `inspector-before.png` and `docked.png` show the placement change. This is a separate defect, not proof of the reported strip's cause.

## Repeatable check

`scripts/webkit/toolbar-rows.mjs` adds foreground `toolbar-collapse`. It checks full visible geometry, native phase routing, continued page scrolling, both motion paths, and toolbar restoration. It retains geometry before input and at 100, 400, 1000, and 2000 ms. Timed AppKit caches show the gradient at 10%, 50%, and 90% of page height.

| Neighbor | Evidence |
|---|---|
| Scroll up / top | Native upward gesture clears `scrolledDown` and restores the original viewport height |
| Peek | The mounted strip's `onMouseEnter` handler reaches `mode="peek"`; geometry remains full. Physical tracking remains manual |
| Split view | Native gestures scroll and collapse both mounted panes; both retain full visible geometry |
| Bookmarks and resize | Always-visible bookmarks add collapse height beyond the normal 21 pt; a collapsed 1100×740 window preserves full visible geometry |
| Docked Inspector | Inspector sits below the page; page and Inspector heights sum to their parent height |

AppKit `cacheDisplay`, window layer snapshots, and WebKit snapshots show full content here. They do not establish actual screen pixels. No `CGWindowListCreateImage`, system capture, permission request, or global input posting runs.

## Owner evidence

Click the broken page, then press **Command+Option+Shift+G**. The ordinary app silently replaces `~/.config/ardia-webkit/WebKit/webkit-geometry.json`. With `ARDIA_DATA_DIR`, it writes `<ARDIA_DATA_DIR>/WebKit/webkit-geometry.json`.

The file records page/ancestor and Inspector geometry, visible rectangles, and layer transforms/masks. It adds backing scale, macOS build, WebKit version, system/app motion flags, toolbar mode, and recent window attachments. It records no URLs, titles, page content, pixels, or credentials. The two-line toolbar hook supplies the actual UI state. The approved one-line `pageTypes.ts` entry types its command prefix. The hook uses the existing state re-export. Diagnostic methods live in the existing extension to keep `WebKitTab.swift` below its 600-line cap. The shortcut and JSON output are exercised by the row.

The remaining blocker is geometry from the affected Mac while its screen shows the strip. The manual actions are in [needs-person.md](needs-person.md#toolbar-collapse).

## Repeated Release rows

Three consecutive `scripts/webkit/check --no-build --only toolbar-collapse` runs on the final Release build returned exit 0:

```text
Run 1
| Row | Result | Evidence |
|---|---|---|
| toolbar-collapse | PASS | native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced |
Run 2
| Row | Result | Evidence |
|---|---|---|
| toolbar-collapse | PASS | native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced |
Run 3
| Row | Result | Evidence |
|---|---|---|
| toolbar-collapse | PASS | native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced |
```

Debug/Metro output before those repairs:

```text
Debug toolbar-collapse: native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced
Debug split panes: [ 'collapsed', 'collapsed' ]
```

## Full Release check

`scripts/webkit/check` rebuilt Release and its zip. Exit 0: 77 PASS, two local-profile skips, one NEEDS PERSON, zero FAIL.

| Row | Result | Evidence |
|---|---|---|
| ext-store | PASS | real store button enabled; page world has no handler; authenticated requested id; no install before consent; accepted id survives relaunch and Added button disabled; decline leaves no extension or staging files |
| ext-store-origin | PASS | native denied local main frame and subframe (4/2); page world has neither handler nor test hook; no install prompt or extension |
| ext-gate | PASS | content DOM changed; service worker replied worker-answer; framework popup attached and DOM readable; no password handler/API; no grant before consent |
| ext-install-folder | PASS | consent via resolveInstallPrompt; managed copy survives source removal; Settings snapshot; worker runs; other profile empty |
| ext-install-crx | PASS | CRX3 header and ZIP extracted; Chrome signed-header id preserved; requested hosts accepted through install prompt |
| ext-toggle | PASS | disabled state survives relaunch and injects nothing; enabled/reloaded extension runs after relaunch; uninstall removes record |
| ext-action | PASS | foreground: app active, window key/visible, popup visible with positive dimensions; toolbar icon and badge 8; native mouse closed/reopened popup; DOM readable; password world inaccessible |
| ext-tabs-api | PASS | tabs.query sees real page; tabs.create adopts a real tab; tabs.update navigates it; onUpdated reports its changed URL |
| ext-permissions | PASS | unaccepted install absent; decline rejects without grants; acceptance enables only requested hosts; extension cannot reach password handler/API; private window has no injection; no reprompt after relaunch; sync unsupported |
| pw-save | PASS | plain and two-step page-world form submit; unchanged save event accepted; Settings list contains login; fixture authenticated; logs contain no password |
| pw-fill | PASS | new process fills and authenticates; last-used updated; dynamic form, two-step form and same-origin iframe fill |
| pw-update | PASS | changed submit offers update; accepted password fills; native Settings rename and delete work |
| pw-never | PASS | Never persists and suppresses prompts; allow-saving removes exception; offer/autofill toggle persists and prevents fill |
| pw-two-accounts | PASS | two accounts stay empty until choice; logged NSMenu lists both; native action fills only selected account |
| pw-origin | PASS | https login withheld on http; localhost differs from 127.0.0.1; cross-origin frame, signup and hidden fields receive nothing; hostile page has no handler or isolated API |
| pw-private | PASS | private frame reads base login and fills; changed submit has no prompt; direct save rejected; base ciphertext/last-used and never list unchanged |
| pw-export | PASS | caller-chosen CSV parses through importer; mode 0600; no implicit background path; denied test unlock blocks export/reveal without dialog |
| pw-relaunch | PASS | metadata identical after relaunch; persisted key decrypts login; other profile empty |
| pw-at-rest | PASS | secret bridge hex/invalid/private/oversize inputs wiped; sync read/write explicitly unsupported; grep -a -l -F fixture password: exit 1 for SQLite/WAL/SHM; encrypted BLOB stored; app logs contain no password |
| import-arc-spaces | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3239 ms |
| import-arc-tabs | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3254 ms |
| import-bookmarks | PASS | fixture; source bookmarks=7, history entries=0, visits=0; wrote bookmarks=7, history entries=0; SQLite after relaunch=0,7; 2987 ms |
| import-history | PASS | fixture; source bookmarks=0, history entries=2502, visits=10040; wrote bookmarks=0, history entries=2502; SQLite after relaunch=2502,0; 3231 ms |
| import-arc-local | SKIPPED (no source profile) | local-only; source folder exists but contains no importer-readable profile |
| import-chrome-local | SKIPPED (no source profile) | local-only; source folder exists but contains no importer-readable profile |
| import-cookies | PASS | fixture; wrote cookies=6; next request sent imported session cookie; no Keychain |
| import-honest | PASS | fixture; passwords=4 written through savePassword and retained after relaunch; Android credential rejected and reported failed; addresses=0, cards=0; autofill hidden and reported not imported |
| bookmark-add | PASS | Add to Bookmarks command opened Bookmark Added dialog; Done closed it; native tree and mounted bar contain page |
| bookmark-folder | PASS | folder created/renamed; moveBookmark (drag completion action) reordered within folder and bar; SQLite order 0,1; folder deletion removed both children |
| bookmark-persist | PASS | folder + three links; 6 SQLite rows; removed JS cache; UUIDs, timestamps and order identical after relaunch; snapshot=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-5-evidence/bookmarks-bar.png |
| bookmark-export | PASS | public exportHtml wrote Netscape HTML without panel; real import parser recovered all 3 URLs/titles/dates, nested folder, bar/other roles, UTF-8 and escaped attributes |
| bookmark-profile | PASS | second profile initially empty; independent persisted tree; watch idempotent, model-load event={profile}; apply suppresses events per Chromium |
| bookmark-private | PASS | private window resolves bookmarks to base profile; native tree equals base; upstream intentionally hides private bar; no private SQLite; base unchanged |
| zoom-site | PASS | zoom step persisted in SQLite; relaunch applied 1.1; other profile retained 1.5; Settings reset updated live page |
| site-settings | PASS | all five allow/block decisions survived two relaunches; profile isolation; Settings origins and reset; real media delegate grant/deny without capture; location storage only (system consent avoided) |
| clear-site-data | PASS | 127.0.0.1 cookies and localStorage cleared after reload; localhost cookies and localStorage retained |
| blocker-controls | PASS | global and EasyList toggles changed actual ad loads; per-host exemption survived relaunch; reset blocked again; Settings count > 0 |
| download-settings | PASS | folder and ask persisted across relaunch; background save-panel path logged; chosen folder used; slow local download paused/resumed to 8 MiB; second cancelled; actual picker needs a person |
| profiles | PASS | loaded/release reflect WebKit stores; profile deletion removed WebKit and SQLite; last private window cleared cookies and site settings; no private SQLite |
| search-engines | PASS | existing core list offers Google/DuckDuckGo/Bing/Kagi; custom choice survived relaunch and typed query loaded local URL; native suggestion transport used local fixture |
| about | PASS | engine.info and ardia://version show WebKit 22625.1.29.11.28, app 0.2.46; no Chromium wording |
| inspector | PASS | Inspect opened a visible frontend with element selection active; detached native window=76105, 1000x650; closed; queued Option+Command+I reopened visible window=76106; inspector.png retained |
| popup-blocked | PASS | timer popup blocked; UI received id/url/origin; open once loaded Cobalt Violet automatic-child; Always allow survived relaunch |
| http-auth | PASS | Basic challenge logged; wrong credentials re-prompted; correct credentials loaded; Cancel displayed actual 401 body; sheet input needs a person |
| load-error | PASS | real refused loopback connection rendered error; injected DNS/offline errors used same delegate; Retry loaded local fixture; failed URL/title preserved |
| page-colors | PASS | native background=#251D1E; pageColor=plum; dark backing installed at attach; white flash needs visual check |
| little-ardia | PASS | native application URL delivery opened small window; Open in Ardia moved same live DOM to main window |
| toolbar-collapse | PASS | native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced |
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
| settings-tour | PASS | 14 panes: general, profiles, sync, tabs, appearance, privacy, passwords, autofill, extensions, search, shortcuts, liveFolders, calendar, advanced; roots rendered; nonblank snapshots; no JS exceptions; /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/settings-tour-evidence |
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:53894/observe-js","http://127.0.0.1:53894/observe-native","http://127.0.0.1:53894/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 292 ms (<10000 ms) |
| smoke-h | PASS | same data dir restored 2 windows and all 3 tab URLs |
| smoke-i | PASS | personal cookie=personal; second profile initially empty, then cookie=work; first unchanged |
| smoke-j | PASS | two mounted pages with correct titles; widths=576,576 |
| smoke-k | PASS | bundled lists=2; control loaded; local ad blocked; blocked count=1; server received no ad request |
| favicon | PASS | Python icon=8218 characters; same PNG and UI icon after relaunch; snapshot=2720x1720 |
| history | PASS | 3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (4 visits); partial title found Cobalt Violet one |
| history-delete | PASS | deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0 |
| history-private | PASS | private page loaded; visits 3 -> 3; private native add=0; no extra store |
| search | PASS | weath -> 4 network suggestions (weather říčany); typed query loaded Google results |
| native | PASS | PASS WebKit extensions: RSA/ECDSA authentication, tampered payload/header, wrong id, truncation, store origin/URL; CRX3 bounds/version/payload/id, stable Chrome alphabet, folder symlink rejection, ZIP traversal/symlink rejection; PASS WebKit passwords: AES-GCM round trip/tamper/AAD, key isolation/reuse/loss, metadata, duplicate/update/remove, exceptions, CSV mode/symlink, exact origins, five form fixtures; PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion; PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard, queued literal/hardware keys, menu validation, inspector SPI, phased scroll metadata/retargeting; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2261/2262 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |
Manual checklist: /Users/schovi/work/ardia-webkit/docs/webkit/needs-person.md
