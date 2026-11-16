# Step 6: import

Implementation commit: `98cafb89e`.

Fixture imports work through the Release import window. Real imports remain unproven: both local source folders contain zero supported input files. Both local-only rows report `SKIPPED (no source profile)`.

Baseline at `be094ea37`: exit 0, 46 PASS, 4 no-key-window skips, 2 NEEDS PERSON. No edits preceded that run.

## Engine writes

| Import path | Destination | Result |
|---|---|---|
| `history.import` → `ac_history_import` | Profile SQLite `pages` and `visits` | Added handler and dispatch. Preserves aggregate visit counts and latest known visit. Reimport keeps existing entries. |
| `bookmarks.apply` | Profile SQLite `bookmarks` | Step 5 implementation; hierarchy, root roles, titles and order verified. |
| `adoptFavicons` → `ac_favicons_set` | SQLite icons and JS cache | Existing implementation; importer uses it unchanged. No separate new favicon comparison. |
| `writeImported` → `callWithSecret(ac_cookies_import)` | Existing WebKit cookie writer and profile `WKWebsiteDataStore` | Added native bridge, input-buffer wiping and private-profile rejection. |
| `savePassword` | Unsupported until Step 7 | Import no longer calls it. Selection hidden; counts stay zero; result says not imported. |
| `writeImported` → `ac_autofill_import` | Unsupported | Selection hidden; secret bridge returns an explicit unsupported error. Counts stay zero. |
| Tabs, pinned rows, folders, splits, spaces, themes | Existing JS store | No new native destination. Fixture comparisons prove membership, relative order and theme presence. |

The existing wizard puts the first Arc space into the selected destination profile and creates profiles for later spaces. The checks compare relative pinned-row and folder-link order; they do not prove every possible interleaving of folders and rows.

The native history test covers malformed rows, repeat import, aggregate visits and reopening. Native secret-bridge tests cover malformed JSON, unsupported calls and input wiping. The cookie row rejects private-profile writes and proves delivery to the next fixture request. Two JS tests prevent unsupported password counts and unsupported unlock selections. The importer Swift suite passes 79 tests.

## A. Import rows

The full-check table below contains source and destination counts. The Arc fixture has 3 spaces, 2 ordinary tabs, 7 pinned links, and 3 folders. Two folders become groups; one split folder becomes a split view. Two spaces supply themes. The Chrome fixture has 7 bookmarks and 2,502 history entries with 10,040 aggregate visits. The cookie fixture writes 6 cookies and proves session-cookie delivery to the server.

Real Arc and Chrome import duration: unavailable. Each copied zero supported input files, so neither import started or wrote items. No real cookies, passwords, autofill or Safari access ran. The local rows never call unlock.

## B. Snapshot

`apps/browser/build-webkit/step-6-evidence/arc-fixture-sidebar.png`

This is an in-process fixture snapshot. No real-data snapshot exists. It does not prove a foreground window or physical input.

## Privacy and cleanup

The copy helper accepts only importer input filenames and profile directories. It omits cookies, password databases, autofill, sessions, caches and blobs. A fixture self-check verifies the allowed and excluded files.

The real-source audit printed:

```text
arc copied input files=0
chrome copied input files=0
grep -F -f <scratch>/private-patterns.txt <scratch>/commit-diff.patch
source strings=0; grep exit=1; matching lines=0
scratch listing=[]
```

The grep compared the complete patch from `be094ea37` with strings from the copied inputs. Zero source strings makes this audit vacuous; no real data entered the importer. The code contains only invented fixture data. Local row cleanup printed `listing=[]` for both copies, and the checker removed its scratch root. Originals were never opened as databases or written.

## Plan and README corrections

- The source folders exist, but neither contains importer-readable inputs. Folder existence alone does not prove that a real import can run.
- `history.import` had no dispatch or store implementation. Ordinary history writes did not prove import support.
- The WebKit cookie writer existed, but the importer's secret bridge remained a stand-in. The importer never reached that writer.
- `acImport` was Debug-only. Release checks now enable only that handle in isolated test instances.
- The first full run found a forbidden UI-to-platform import in the new harness gate. Reusing `perfProbeEnabled` removed that dependency; the conventions check passed.
- Hermes evaluation cannot parse async functions. Harness scripts use promise chains.
- The older import end-to-end script requires Chromium CDP and working autofill. This fork uses the new check rows instead.

An early fixture runner reused the same destination for two Arc rows. A repeated import then waited on the profile-conflict path. Each row now gets a fresh directory. Its owned hung instance was terminated. A separate native test initially cleared its shared history store; an isolated import store fixed the test setup.

No additional malformed stand-in default needed repair. Password storage remains Step 7 work.

## Limits

Real-profile shape, scale, source timings and real cookie decryption remain unproven. The cookie row proves fixture delivery, not exhaustive cookie attributes, repeat-import merge semantics or persistence after relaunch. Password storage and autofill remain unsupported. Safari, physical import-window interaction and foreground rendering did not run. Existing upstream scripts and unrelated UI issues remain outside Step 6.

## C. Full check

Exit 0: 52 PASS, 4 `SKIPPED (no key window)`, 2 `SKIPPED (no source profile)`, 2 NEEDS PERSON. Release app and zip rebuilt. JS: 2260/2261 tests; only the named baseline failure remains; typecheck passed.

| Row | Result | Evidence |
|---|---|---|
| import-arc-spaces | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3207 ms |
| import-arc-tabs | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3272 ms |
| import-bookmarks | PASS | fixture; source bookmarks=7, history entries=0, visits=0; wrote bookmarks=7, history entries=0; SQLite after relaunch=0,7; 3017 ms |
| import-history | PASS | fixture; source bookmarks=0, history entries=2502, visits=10040; wrote bookmarks=0, history entries=2502; SQLite after relaunch=2502,0; 2996 ms |
| import-arc-local | SKIPPED (no source profile) | local-only; source folder exists but contains no importer-readable profile |
| import-chrome-local | SKIPPED (no source profile) | local-only; source folder exists but contains no importer-readable profile |
| import-cookies | PASS | fixture; wrote cookies=6; next request sent imported session cookie; no Keychain |
| import-honest | PASS | fixture; passwords=0, addresses=0, cards=0; selection hidden; result says not imported |
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
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:56846/observe-js","http://127.0.0.1:56846/observe-native","http://127.0.0.1:56846/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 295 ms (<10000 ms) |
| smoke-h | PASS | same data dir restored 2 windows and all 3 tab URLs |
| smoke-i | PASS | personal cookie=personal; second profile initially empty, then cookie=work; first unchanged |
| smoke-j | PASS | two mounted pages with correct titles; widths=576,576 |
| smoke-k | PASS | bundled lists=2; control loaded; local ad blocked; blocked count=1; server received no ad request |
| favicon | PASS | Python icon=8218 characters; same PNG and UI icon after relaunch; snapshot=2720x1720 |
| history | PASS | 3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (4 visits); partial title found Cobalt Violet one |
| history-delete | PASS | deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0 |
| history-private | PASS | private page loaded; visits 3 -> 3; private native add=0; no extra store |
| search | PASS | weath -> 4 network suggestions (weather říčany); typed query loaded Google results |
| native | PASS | PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion; PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2260/2261 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |

## Files

```text
apps/browser/src/components/dev/devRegister.ts
apps/browser/src/components/import/steps/ChooseStep.tsx
apps/browser/src/components/import/steps/DoneStep.tsx
apps/browser/src/state/import/apply.ts
apps/browser/src/state/import/flow.ts
apps/browser/src/state/import/unsupportedImports.test.mjs
docs/webkit/execution-plan.md
docs/webkit/standins.md
docs/webkit/step-6-results.md
packages/ardiacore/ios/WebKitCookieImport.swift
packages/ardiacore/ios/webkit/EngineBridge.mm
packages/ardiacore/ios/webkit/Standins.mm
packages/ardiacore/ios/webkit/Store.mm
packages/ardiacore/tests/webkit-data.test.mm
packages/import/README.md
scripts/webkit/README.md
scripts/webkit/check.mjs
scripts/webkit/check.test.mjs
scripts/webkit/fixture.mjs
scripts/webkit/import-rows.mjs
scripts/webkit/report.mjs
scripts/webkit/rows.mjs
scripts/webkit/support.mjs
```
