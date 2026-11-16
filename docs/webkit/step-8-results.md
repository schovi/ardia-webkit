# Step 8 extensions

Baseline at `bd5ec5dd6`: exit 0, 62 PASS, 6 SKIPPED, 2 NEEDS PERSON. No edits preceded that run.

## A. Gate

All three proofs passed in a hidden instance before production UI wiring:

```text
content: {"extensionContent":"changed","extensionWorker":"worker-answer"}
popup: Popup loaded
attached: true
```

The repeatable `ext-gate` row additionally proves no injection before consent and no access to the password handler or isolated API. The native test hook emits the app's install prompt. The harness answers through `extensions.resolveInstallPrompt`.

The deployment target stays macOS 14. Native extension code uses availability guards for macOS 15.4.

## B. Behaviour

| Row | Evidence |
|---|---|
| ext-install-folder | Accepted hosts through the existing prompt; managed copy survives source deletion; Settings renders it; another profile stays empty. |
| ext-install-crx | CRX3 header plus ZIP installs; the signed-header Chrome id remains the UI id. |
| ext-toggle | Disabled state survives relaunch and injects nothing. Enabled and reloaded state runs after relaunch. Removal deletes the record and files. |
| ext-action | Foreground app is active; its window is key and visible. Native mouse events close and reopen the popup. Its DOM, dimensions, and ancestor opacity prove visible content. The snapshot shows the popup, icon, and badge. |
| ext-tabs-api | Query sees real tabs; create adopts a real tab; update navigates it; onUpdated reports the changed URL. |
| ext-permissions | No record before acceptance. Decline removes the pending copy. Accepted scopes persist. Private windows have no extension controller. Password handler/API probes both return false. |
| ext-store | Report only. No installation bridge exists. See below. |

One controller serves each regular profile and uses that profile's website data store. SQLite profile settings hold metadata and grants. Managed extension files stay under the app's data directory. Chrome ids become WebKit context identifiers and stable `webkit-extension` origins.

The native module keeps the upstream call table and overrides extension operations with WebKit handlers. Unused Chromium service selectors remain stand-ins.

The popup host waits for WebKit loading to finish and emits the existing `preferredSize` event. This starts the existing UI's size and appearance animation.

The existing popup UI hosts the framework's web view. It does not use a popover fallback. The default native view now constructs a WebKit page, including standalone extension hosts that omit the React engine prop.

## C. Real release archives

Both archives came from their projects' public GitHub releases. Each unpacked into its own empty scratch folder. No downloaded script ran outside WebKit. Each install received explicit acceptance through the same resolver as the UI.

| Extension | Observed result |
|---|---|
| [uBlock Origin Lite 2026.1116.1650](https://github.com/uBlockOrigin/uBOL-home/releases/tag/2026.1116.1650), Chromium archive | Installed with no recorded errors. Its attached popup DOM contained the fixture host and filtering controls. Blocking effectiveness and rule quotas were not measured. |
| [Bitwarden 2026.10.2](https://github.com/bitwarden/clients/releases/tag/browser-v2026.10.2), Chrome archive | Installed, but the background worker failed: `TypeError: null is not an object (evaluating 'this.device.toString')`. WebKit also reported background content failure. The popup attached; its initial DOM read was empty. No account or vault was used. |

uBOL requested `offscreen` and `userScripts`; WebKit omitted both from its recognized requested permissions. Both namespaces were undefined in its popup. Its `declarativeNetRequest` namespace existed. `MAX_NUMBER_OF_STATIC_RULESETS` existed, while `MAX_NUMBER_OF_DYNAMIC_RULES` was undefined. The probe did not measure numeric quotas or rule-type support.

Bitwarden requested `clipboardRead`, `idle`, `offscreen`, `sidePanel`, and `webRequestAuthProvider`; WebKit omitted those from its recognized requested permissions. `offscreen`, `sidePanel`, and `notifications` were undefined in its popup. WebKit recognized the `notifications` permission but exposed no corresponding namespace there. Its nonblocking `webRequest.onBeforeRequest` event existed. Blocking webRequest was not requested or tested. Apple documents [`webRequestBlocking` and blocking responses as unsupported in Safari web extensions](https://developer.apple.com/documentation/safariservices/assessing-your-safari-web-extension-s-browser-compatibility). This probe does not independently establish that entire Safari compatibility table for WKWebExtension.

Bitwarden lists `nativeMessaging` as optional. The install did not grant optional permissions. Both native-message methods were undefined in the tested popups. This host implements no native-message delegate. That result does not prove WebKit cannot support native messaging: Apple's [controller delegate API](https://developer.apple.com/documentation/webkit/wkwebextensioncontrollerdelegate) includes native-message callbacks.

The probes ran against Release build `2657c14b07f478bd5f128633215d1cf4636daf5357513ce996c6e5dc1de0bd1a` (zip SHA-256), before the final stable-origin and file-access changes. They establish API exposure and startup compatibility, not complete extension functionality.

```text
download cleanup /tmp/ardia-step8-downloads exists=false listing=[]
```

## Chrome Web Store report

The Web Store has no install bridge here. The app identifies its pages as Safari. A working Add to Chrome flow needs browser eligibility handling, an origin-restricted installation bridge, CRX download handling, package authentication, and the existing consent flow. Automatic updates need a separate implementation.

Google documents the [Web Store update endpoint and extension ids](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions). The bridge design above is an implementation inference, not a claim that Google supports this browser. This step implements none of it.

## Limits and corrections

- `ArdiaExtensionPackage.mm` is engine-free, but it reads manifests and derives ids. It does not unpack CRX files. The new archive helper handles CRX3 and safe ZIP extraction.
- `WebKitTab.extensionHost` was not the only stub involved. Standalone popups selected `ChromiumTabView` by default. Native routing needed repair.
- Local CRX installation parses the signed header but does not authenticate signatures. Duplicate ids cannot replace an installed extension.
- Configure supports toolbar pinning. Incognito opt-in, file-access opt-in, site-access editing, optional permission prompts, side panels, and extension sync remain unsupported. The host blocks file-page access and never loads extensions in private windows.
- Native in-app mouse clicking, outside dismissal, reopening, and visible popup content passed in foreground mode. Physical input, focus, Esc dismissal, appearance, and Settings input remain in `needs-person.md`. Extension updates, extension-owned pages as normal tabs, advanced tab/window options, dynamic popup paths, arbitrary third-party extensions, blocking webRequest, and complete DNR compatibility remain unchecked.

Apple documents [controller loading](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller/load(_:)), [resource initialization](https://developer.apple.com/documentation/webkit/wkwebextension/init(resourcebaseurl:)), [popup hosting](https://developer.apple.com/documentation/webkit/wkwebextension/action/popupwebview), and [custom base URLs](https://developer.apple.com/documentation/webkit/wkwebextensioncontext/baseurl).

Extension startup adds synchronous settings reads. Those reads opened SQLite beside history's worker, so schema setup raced. Settings reads, writes, and deletion now use the existing store queue. Notifications stay outside the queue. The busy timeout also precedes WAL setup. Main-thread settings calls can now wait for queued store work. No SQL schema or timeout value changed.

Three diagnostic cold launches reproduced SQLite error 5 during schema setup before serialization. Three fresh launches after serialization logged no JavaScript exceptions. The repaired Settings tour and native checks passed. The native suite also checks a held writer and concurrent extension-settings writes.

```text
Before: FAIL profile opening waits for a concurrent startup writer before enabling WAL
After: native PASS
```

The first full run also reached foreground checks that the baseline skipped. `type-page` and `full-screen` passed. `type-omnibox` failed to restore page focus after Esc. `keys-page-focus` failed to return to the expected title after Cmd+[. Both failures reproduced alone. These paths belong to Step 2; no check was weakened or skipped.

## Foreground rows now

The Mac now grants a key window. The baseline skipped four rows for lack of one. The final table below retains every actual status. The owner authorized the Step 2 failures to remain FAIL and kept their fixes outside Step 8.

| Row | Result | Evidence |
|---|---|---|
| type-page | PASS | synthetic click, native keys: hello; Tab to second; Cmd+C/V copied hello; system focus needs a person |
| type-omnibox | FAIL | Timed out: return ac.engine.call("webKit.devPageState",{tabId:"tab-mwjq3khlks08-2"}).then(s=>s.focused);; last=false |
| keys-page-focus | FAIL | Timed out: const t=ac.store.getState().tabs["tab-mwjq3ykgebq0-2"];return t&&ac.webviews.has(t.id)&&t.title==="Cobalt Violet keyboard";; last=false |
| full-screen | FAIL | Timed out: return ac.webviews.get("tab-mwjq52bwoz91-2").evaluate('post("result",JSON.stringify(document.fullscreenElement?.id==="stage"));');; last=false |
| inspector | NEEDS PERSON | Inspect and Developer Tools command reached private _inspector; selectors present; inspectable=true; background mode suppressed UI; actual inspector and shortcut need a key window |
| swipe | NEEDS PERSON | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |

`full-screen` passed an earlier run but failed the final run at element entry. The row and implementation remain unchanged. The owner directed any additional newly reachable foreground failures to the orchestrator. This step made no Step 2 repair and did not investigate the final full-screen failure.

## D. Full check

`scripts/webkit/check` rebuilt Release and the zip. It exited **1**: **70 PASS, 3 FAIL, 2 SKIPPED, 2 NEEDS PERSON**. All seven extension rows passed. The three failures are the unchanged foreground Step 2 rows listed above. The owner explicitly excluded their repair from Step 8. No other row failed.

```text
** BUILD SUCCEEDED **
f7306052c17e093cdd6bb0105c624d6ed390a8cc1c4de8733f955094efca9870  apps/browser/build-webkit/Ardia-WebKit-Release.zip
scratch removed: /var/folders/9x/1553_lzj34j8yz09hjnr2y9h0000gp/T/ardia-webkit-check-smb4uK
```

The final log is `apps/browser/build-webkit/step-8-evidence/full-check.log`. The popup snapshot is `apps/browser/build-webkit/step-8-evidence/extension-popup.png`; Settings is `apps/browser/build-webkit/step-8-evidence/extensions.png`.

| Row | Result | Evidence |
|---|---|---|
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
| import-arc-spaces | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3258 ms |
| import-arc-tabs | PASS | fixture; source spaces=3, tabs=2, pinned tabs=7, folders=3; matched tabs=9, destination spaces=3, folders=2, themes=2; relative order preserved; wrote tabs=9; 3226 ms |
| import-bookmarks | PASS | fixture; source bookmarks=7, history entries=0, visits=0; wrote bookmarks=7, history entries=0; SQLite after relaunch=0,7; 2990 ms |
| import-history | PASS | fixture; source bookmarks=0, history entries=2502, visits=10040; wrote bookmarks=0, history entries=2502; SQLite after relaunch=2502,0; 2980 ms |
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
| type-page | PASS | synthetic click, native keys: hello; Tab to second; Cmd+C/V copied hello; system focus needs a person |
| type-omnibox | FAIL | Timed out: return ac.engine.call("webKit.devPageState",{tabId:"tab-mwjq3khlks08-2"}).then(s=>s.focused);; last=false |
| keys-page-focus | FAIL | Timed out: const t=ac.store.getState().tabs["tab-mwjq3ykgebq0-2"];return t&&ac.webviews.has(t.id)&&t.title==="Cobalt Violet keyboard";; last=false |
| traffic-lights | PASS | explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=[[40,30],[63,30],[86,30]]; normal.png retained; visible layout needs a person |
| close-window | PASS | native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive |
| full-screen | FAIL | Timed out: return ac.webviews.get("tab-mwjq52bwoz91-2").evaluate('post("result",JSON.stringify(document.fullscreenElement?.id==="stage"));');; last=false |
| user-sees | PASS | visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person |
| profile-switch | PASS | same window switched profile; work initially isolated, then work cookie; personal cookie survived return |
| swipe | NEEDS PERSON | allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition |
| context-menu | PASS | synthetic right-click link menu=Open Link,Open Link in New Tab,Download Linked File,Copy Link,,Share…,,Play All Animations,,; open tab and copy link proven; page menu=Look Up “Link”,Translate “Link”,,Search with Google,,Copy,Copy Link with Highlight,,Share…,,,Show Writing Tools,Summarize,,Speech,,Play All Animations,,; real mouse needs a person |
| settings-tour | PASS | 14 panes: general, profiles, sync, tabs, appearance, privacy, passwords, autofill, extensions, search, shortcuts, liveFolders, calendar, advanced; roots rendered; nonblank snapshots; no JS exceptions; /Users/schovi/work/ardia-webkit/apps/browser/build-webkit/settings-tour-evidence |
| no-upstream | PASS | 90 seconds; onboarding completed; JS and native controls observed; requests=["http://127.0.0.1:51483/observe-js","http://127.0.0.1:51483/observe-native","http://127.0.0.1:51483/favicon.ico"]; snapshots=/Users/schovi/work/ardia-webkit/apps/browser/build-webkit/step-1-evidence |
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
| native | PASS | PASS WebKit extensions: CRX3 bounds/version/payload/id, stable Chrome alphabet, folder symlink rejection, ZIP traversal/symlink rejection; PASS WebKit passwords: AES-GCM round trip/tamper/AAD, key isolation/reuse/loss, metadata, duplicate/update/remove, exceptions, CSV mode/symlink, exact origins, five form fixtures; PASS WebKit bookmarks: add, stable UUIDs, sync key, move, reorder, cycles, partial batches, invalid URLs, ifAbsent, folder deletion; PASS WebKit data: persistence, isolation, deduplication, deletion, limits, favicon, requests, settings shapes and pane snapshots; PASS WebKit window: close policy, root ownership, light coordinates, visibility defaults, quit callback, reserved key guard; PASS WebKit page: escaped errors, retry link, popup persistence, profile/origin isolation, private grants |
| js | PASS | 2261/2262 JS tests; only allowed: a watch from someone not sharing turns sharing on for 14 days and tags every event; typecheck passed |


## Files and commits

Implementation: `0a5e4a451 Add per-profile WebKit extensions and popup hosting`. The following documentation commit records the final check and updates progress and endpoints. Nothing was pushed.

```text
apps/browser/macos/Podfile.lock
docs/webkit/execution-plan.md
docs/webkit/needs-person.md
docs/webkit/standins.md
docs/webkit/step-8-results.md
docs/webkit/upstream-endpoints.md
packages/ardiacore/ios/ArdiaCore.podspec
packages/ardiacore/ios/ChromiumTabView.swift
packages/ardiacore/ios/ExtensionsModule.swift
packages/ardiacore/ios/WebKitExtensionActions.swift
packages/ardiacore/ios/WebKitExtensionArchive.swift
packages/ardiacore/ios/WebKitExtensionCalls.swift
packages/ardiacore/ios/WebKitExtensionGate.swift
packages/ardiacore/ios/WebKitExtensionTabs.swift
packages/ardiacore/ios/WebKitExtensions.swift
packages/ardiacore/ios/WebKitHub.swift
packages/ardiacore/ios/WebKitModule.swift
packages/ardiacore/ios/WebKitTab+PageTab.swift
packages/ardiacore/ios/WebKitTab+UIDelegate.swift
packages/ardiacore/ios/WebKitTab.swift
packages/ardiacore/ios/webkit/EngineBridge.mm
packages/ardiacore/ios/webkit/ExtensionPackage.mm
packages/ardiacore/ios/webkit/Services.mm
packages/ardiacore/ios/webkit/Standins.mm
packages/ardiacore/ios/webkit/Store.mm
packages/ardiacore/tests/webkit-data.test.mm
packages/ardiacore/tests/webkit-extensions.test.swift
scripts/webkit/README.md
scripts/webkit/extension-rows.mjs
scripts/webkit/fixtures/extension-content/background.js
scripts/webkit/fixtures/extension-content/content.js
scripts/webkit/fixtures/extension-content/icon.svg
scripts/webkit/fixtures/extension-content/manifest.json
scripts/webkit/fixtures/extension-content/popup.html
scripts/webkit/fixtures/extension-tabs/background.js
scripts/webkit/fixtures/extension-tabs/content.js
scripts/webkit/fixtures/extension-tabs/manifest.json
scripts/webkit/fixtures/extension-tabs/popup.html
scripts/webkit/rows.mjs
scripts/webkit/window-rows.mjs
```
