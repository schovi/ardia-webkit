# Step 7 passwords

Baseline at `e21abfd5e`: exit 0, 52 PASS, 6 SKIPPED, 2 NEEDS PERSON. No edits preceded that run.

## A. Password rows

The full check table appears below. Passwords use the existing settings and prompt UI. Web logins import through `ArdiaServices.savePassword`. Password sync rejects reads and writes explicitly. The sync package changed by one line.

The native menu logs usernames and enabled flags in background mode. Its pick file invokes the actual selected menu action. Form submissions run in the page world. Fill runs in its own content world, then the fixture server authenticates the filled values.

## B. Native checks

```text
PASS WebKit passwords: AES-GCM round trip/tamper/AAD, key isolation/reuse/loss, metadata, duplicate/update/remove, exceptions, CSV mode/symlink, exact origins, five form fixtures
```

Additional assertions cover key-file mode 0600, key-lock contention, input-buffer wiping, invalid UTF-8 and hex, NUL usernames, hidden and zero-sized fields. Five real WKWebView fixtures cover plain login, password-only second step, signup, iframe, and a form created after load. The iframe check inspects the actual child frame. The app rows prove username transfer across navigation and same-origin iframe fill.

## Security requirements

| Requirement | Implementation | Proof |
|---|---|---|
| 1. Encrypted storage | `packages/ardiacore/ios/WebKitPasswordVault.swift:125` creates one 256-bit key per directory. AES-GCM authenticates profile, origin and username. `WebKitPasswords.swift:7` selects the existing key-store abstraction. | Native round trip, tamper, profile substitution, key reuse/isolation/loss and lock tests; `pw-at-rest` checks SQLite and sidecars with grep. |
| 2. No real Keychain or dialogs in tests | `packages/ardiacore/ios/WebKitPasswords.swift:11` selects FileKeyStore for isolated instances. Line 25 answers unlock from `reauth`. | `pw-export` tests granted and denied authentication; all launches use scratch data and the file keychain. No real authentication ran. |
| 3. Exact origins | `packages/ardiacore/ios/WebKitPasswordVault.swift:6` canonicalizes scheme, host and port once. Lookups use equality. | Native scheme, host, port, default-port, IPv6 and subdomain cases; `pw-origin` checks host separation and HTTP downgrade. |
| 4. Correct frame | `packages/ardiacore/ios/WebKitTab+Passwords.swift:33` compares WKFrameInfo.securityOrigin with the top page origin. Fill targets that frame. | `pw-fill` fills a same-origin iframe. `pw-origin` checks native rejection and an empty cross-origin password field. |
| 5. Isolated world | `packages/ardiacore/ios/WebKitHub.swift:91` registers a dedicated password world. Line 116 checks the message world. | Native tests inspect the page world's missing handler. The hostile fixture tries both handler names, a custom event and postMessage; `pw-origin` verifies no exposed handler or isolated API. |
| 6. Native chooses | `packages/ardiacore/ios/WebKitTab+Passwords.swift:50` looks up the native origin. Line 71 selects one login automatically or offers the native menu. | `pw-two-accounts` proves no automatic fill, both menu entries, and only the selected account's values. `pw-fill` verifies input events and successful login. |
| 7. Visible login fields only | `packages/ardiacore/ios/WebKitPasswordScript.swift:10` rejects hidden, disabled, readonly, zero-sized and offscreen fields. Line 35 rejects multiple password fields. Line 97 rechecks after username events. | Native visibility cases and signup fixture; `pw-origin` rejects signup and hidden forms. |
| 8. No password logging | `packages/ardiacore/ios/WebKitTab+Passwords.swift:84` emits prompt metadata only. Native password implementations contain no NSLog or print calls. | Password rows scan app logs. Prompt assertions reject a password field in the event. Evidence uses invented fixtures; grep prints filenames only. |
| 9. Private profiles | `packages/ardiacore/ios/WebKitPasswords.swift:16` reads the base profile. Line 36 rejects mutations. `WebKitTab+Passwords.swift:52` blocks capture; line 96 skips last-used writes. | `pw-private` fills from the base profile, rejects saving, and leaves ciphertext, last-used and exceptions unchanged. Native initialization rejects private stores. |
| 10. Memory | `packages/ardiacore/ios/WebKitPasswordVault.swift:45` wipes owned mutable buffers through `webkit/Passwords.mm:9` and ardia_runtime::WipeSecret. `webkit/EngineBridge.mm:13` wipes both input and parsing buffers. | Native zero-buffer assertion; `pw-at-rest` verifies wiping after valid, invalid, oversized and private writes. Pending candidates expire and clear on close or resolution. |
| 11. Export | `packages/ardiacore/ios/WebKitPasswords.swift:37` authenticates export. `WebKitPasswordVault.swift:197` writes Chrome CSV through a mode-0600 staging file. `webkit/Passwords.mm:46` requires a caller path or foreground picker. | `pw-export` parses the CSV with the importer, verifies mode 0600, checks cancellation without a path, and proves denied authentication writes nothing. Native tests verify symlink replacement leaves its target untouched. |

## Plan and README corrections

- The reusable key store lives in the sync pod, which depends on ArdiaCore. A source symlink shares that implementation without a dependency cycle.
- CocoaPods ignored the attempted external source glob. The symlink enters its existing Swift source glob and builds successfully.
- Password handling uses `WebKitPasswordScript.swift` in a separate content world. It does not share the media script's message path.
- Navigation clears the JS password prompt. Native re-emits a pending prompt after navigation finishes. The first save row exposed this race.
- The import fixture contains an Android credential and an undecryptable record. The row checks every supported web credential's count and the explicit Android rejection.

An initial test preparation unlocked the source browser before the wizard. The wizard then skipped its unlock step. Clearing fixture keys before the wizard restored the intended precondition. No check was weakened.

The first native run exposed an integer binding for an initial last-used timestamp. The binder now handles integers explicitly. The conventions check caught the tab file exceeding 600 lines. Password state moved into its own file; the cap and baseline stayed unchanged.

No unrelated stand-in default needed repair. Password Settings still contains upstream advice about extension password managers. Extension support remains Step 8 work.

## Person checks and limits

Four rows were added to `needs-person.md`: physical typing and prompt acceptance; native menu placement and selection; real unlock/reveal/edit/export; ad hoc Keychain access. macOS Passwords integration remains unchecked.

The real Keychain, Touch ID, login-password authentication, and visible export picker did not run. No real browser passwords entered these tests. No HTTPS fixture server ran because certificate dialogs are outside unattended checks. Native origin tests and a synthetic stored HTTPS login presented to HTTP cover the scheme boundary.

Threat cases considered but not exhaustively covered: navigation during a visible menu, concurrent browser processes, power loss during key creation or export, unusual CSS transforms or occlusion, and nonstandard or shadow-DOM login widgets. Key-lock contention and document-token checks exercise specific protections, not a full race stress test. Spreadsheet interpretation of exported cells remains the CSV consumer's behavior.

The implementation cannot prevent same-origin page scripts from reading filled DOM values. It does not defend against a compromised WebKit/native process, a debugger, or a compromised local account. Mutable owned buffers are wiped; Swift, CryptoKit and WebKit can retain internal immutable copies beyond our control.

## C. Full check

Exit 0: 62 PASS, 6 SKIPPED, 2 NEEDS PERSON. Release app and zip rebuilt. JS: 2261/2262 tests, only the named baseline failure; typecheck passed.

Zip SHA-256: `6de4b8091f6053cbe66fc9f867f5516e6b73d20b6ed0d0145cf1ed2c9a9701d4`.

| Row | Result | Evidence |
|---|---|---|
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
| import-arc-spaces | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3243 ms |
| import-arc-tabs | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3251 ms |
| import-bookmarks | PASS | fixture; source bookmarks=7, history entries=0, visits=0; wrote bookmarks=7, history entries=0; SQLite after relaunch=0,7; 2980 ms |
| import-history | PASS | fixture; source bookmarks=0, history entries=2502, visits=10040; wrote bookmarks=0, history entries=2502; SQLite after relaunch=2502,0; 3228 ms |
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
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:61324/observe-js","http://127.0.0.1:61324/observe-native","http://127.0.0.1:61324/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
| chromium | PASS | otool=0; bundle=0 |
| sign | PASS | deep signature valid; ad hoc; entitlements=0 |
| smoke-a | PASS | bundled JS; window snapshot valid; typed URL title=Cobalt Violet typed |
| smoke-b | PASS | 5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain |
| smoke-c | PASS | back, forward, reload verified; find=2; zoom=1.1 |
| smoke-d | PASS | target=_blank and window.open each loaded a new tab; windows=1 |
| smoke-e | PASS | finished; scratch/downloads/smoke.txt; 28 bytes; contents match |
| smoke-f | PASS | native windows: 2 -> 1 -> 0; app and harness remain alive |
| smoke-g | PASS | willQuit observed; exited in 279 ms (<10000 ms) |
| smoke-h | PASS | same data dir restored 2 windows and all 3 tab URLs |
| smoke-i | PASS | personal cookie=personal; second profile initially empty, then cookie=work; first unchanged |
| smoke-j | PASS | two mounted pages with correct titles; widths=576,576 |
| smoke-k | PASS | bundled lists=2; control loaded; local ad blocked; blocked count=1; server received no ad request |
| favicon | PASS | Python icon=8218 characters; same PNG and UI icon after relaunch; snapshot=2720x1720 |
| history | PASS | 3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (4 visits); partial title found Cobalt Violet one |
| history-delete | PASS | deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0 |
| history-private | PASS | private page loaded; visits 3 -> 3; private native add=0; no extra store |
| search | PASS | weath -> 4 network suggestions (weather říčany); typed query loaded Google results |
| native | PASS | PASS WebKit passwords: AES-GCM round trip/tamper/AAD, key isolation/reuse/loss, metadata, duplicate/update/remove, exceptions, CSV mode/symlink, exact origins, five form fixtures; PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion; PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2261/2262 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |

## Files and commits

Implementation commit: `f81e5d2ac`. The following documentation commit records this evidence and the Progress row. No push ran.

```text
apps/browser/src/components/import/steps/ChooseStep.tsx
apps/browser/src/components/import/steps/DoneStep.tsx
apps/browser/src/state/import/apply.ts
apps/browser/src/state/import/flow.ts
apps/browser/src/state/import/unsupportedImports.test.mjs
docs/webkit/execution-plan.md
docs/webkit/needs-person.md
docs/webkit/standins.md
docs/webkit/step-7-results.md
packages/ardiacore/ios/ArdiaServices.h
packages/ardiacore/ios/WebKitHub.swift
packages/ardiacore/ios/WebKitModule.swift
packages/ardiacore/ios/WebKitPasswordKeyStore.swift
packages/ardiacore/ios/WebKitPasswordScript.swift
packages/ardiacore/ios/WebKitPasswordVault.swift
packages/ardiacore/ios/WebKitPasswords.swift
packages/ardiacore/ios/WebKitTab+PageTab.swift
packages/ardiacore/ios/WebKitTab+Passwords.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/webkit/EngineBridge.mm
packages/ardiacore/ios/webkit/Passwords.mm
packages/ardiacore/ios/webkit/Standins.mm
packages/ardiacore/tests/webkit-data.test.mm
packages/ardiacore/tests/webkit-password-buffer.mm
packages/ardiacore/tests/webkit-passwords.test.swift
packages/sync/ios/SyncModule.swift
scripts/webkit/README.md
scripts/webkit/check.test.mjs
scripts/webkit/fixture.mjs
scripts/webkit/import-rows.mjs
scripts/webkit/password-rows.mjs
scripts/webkit/rows.mjs
scripts/webkit/support.mjs
```
