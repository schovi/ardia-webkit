# Step 5: bookmarks

Implementation commit: `5540bf2b5`.

SQLite stores the bookmark tree per profile. The JS bookmark API and UI remain unchanged.

Baseline at `a45d4bc2b`: exit 0, 40 PASS, 4 `SKIPPED (no key window)`, 2 `NEEDS PERSON`. No edits preceded that run.

## A. Bookmark rows

The six bookmark rows below cover the command and rendered dialog, folder operations, relaunch without the JS cache, Netscape export, profile isolation, and private reads.

The bar snapshot contains Reading, One, Two, and Three:

`apps/browser/build-webkit/step-5-evidence/bookmarks-bar.png`

The export row uses `ArdiaImport.importBookmarksHTML`, the existing importer, to parse the actual exported file. It compares all URLs, titles, second-resolution dates, nested folder contents, and root roles. It includes UTF-8 text and escaped title and URL characters.

## B. Native op tests

`packages/ardiacore/tests/webkit-bookmarks.test.mm` runs inside the existing native row. It checks add, UUIDs, sync keys, timestamps, moves, reorder in both directions, index clamping, cycle rejection, permanent roots, invalid URLs, malformed batches, partial results, duplicate adds with and without `ifAbsent`, and recursive folder deletion.

## Contract and Step 6

`engine/chromium/src/chrome/browser/ardia/ac_bookmarks.cc` defines the contract. The native tree returns lowercase UUIDs and ordered children under `bar` and `other`. Operations accept either root alias or the returned UUID. SQLite stores explicit parent and position columns. A transaction commits each batch. A malformed operation rejects the entire batch before mutation. A missing node or parent stops processing; invalid new URLs enter `invalid` and processing continues.

Chromium suppresses `bookmarks.changed` during `apply` through `Watcher::set_applying`. This implementation preserves that behavior. Watch registers once per profile and emits the initial model-load event through `ArdiaEvents`, with only `{profile}`. No other native bookmark mutation path exists in this fork. UI edits already update the JS store before persistence. External SQL edits are not watched.

`apps/browser/src/state/sync/adapters.ts` maps legacy keys to deterministic lowercase UUIDs with `bookmarkUuidFor`. Native storage preserves the optional `key`, original added timestamp, UUID, and child order. Sync uses `bar` and `other` as parent keys and converts ordered children into position strings. Repeated adds with `ifAbsent` preserve existing data.

`apps/browser/src/state/import/apply.ts` generates new UUIDs through `addBookmarkTree`. It preserves source order and nesting, sends toolbar items to `bar`, and sends remaining items to `other`. It wraps incoming items in an imported folder when a destination already contains children. No import or sync source changed.

Private UI code resolves bookmark ownership to the base profile. Native private bookmark calls also resolve to that profile and create no private database. Upstream deliberately hides the private bar in `state/bookmarks/hooks.ts`.

## Plan and README corrections

- The plan's “Today it answers nil” predates Step 1's shaped tree/watch placeholders.
- The plan does not specify that Chromium suppresses change events during `apply`. The profile row verifies that behavior.
- The README did not describe background bookmark export. It now documents the scratch destination and panel bypass.
- An initial test incorrectly expected a visible private bar. Code inspection proved upstream hides it. The corrected row checks base-profile reads and the absence of private bar items. No UI source changed.

Interrupting an earlier check left its owned bookmark-folder instance running after scratch removal. It was stopped explicitly. The checker interruption cleanup remains unchanged.

No additional malformed stand-in response needed repair. No public-header stand-in method changed; regenerating `Standins.mm` produced no diff.

## Manual checks and limits

`needs-person.md` adds physical drag reorder, bookmark dialog keyboard/editing, and the foreground export picker with cancel. Automation proves the same reorder action and the rendered Done button, but not physical input or the save panel.

No real-profile import, cross-device sync, third-party browser import UI, large-tree performance, or exhaustive Chromium URL canonicalization comparison ran. Step 6 still owns importer verification. The snapshot renders in process and does not prove a visible foreground window.

## C. Full check

Exit 0: 46 PASS, 4 `SKIPPED (no key window)`, 2 `NEEDS PERSON`. Release app and zip rebuilt.

| Row | Result | Evidence |
|---|---|---|
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
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:54598/observe-js","http://127.0.0.1:54598/observe-native","http://127.0.0.1:54598/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
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
| native | PASS | PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion; PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2258/2259 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |
