# Execution plan: from "boots on WebKit" to "daily driver"

Written 2026-11-16. Branch `webkit`, at commit `55cf93045`. This file is the source of truth for the remaining work. One Codex worker executes one step at a time. The orchestrator checks each result, pushes, and starts the next step.

Background and decisions: [engine-swap-plan.md](engine-swap-plan.md). Facts about upstream: [learnings.md](learnings.md).

## Where we are

Done and verified:

| Area | State |
|---|---|
| No Chromium in the app | `otool -L` and bundle search find 0 references |
| Boot, plain `NSWindow`, React Native UI | Works. `packages/shell` unchanged |
| Tabs on `WKWebView` | Every tab. `engines.ts` returns `webkit` |
| Tabs, navigation, find, zoom, popups, split view, second window, quit, session restore, per-profile cookies, downloads, content blocker | Smoke pass, 11 rows |
| Favicons, history, search suggestions | Native SQLite store per profile |
| Release app `Ardia WebKit.app`, own bundle id and data folder | Ad hoc signed, zip in `apps/browser/build-webkit/` |

Not done. Each line is covered by a step below:

| Gap | Step |
|---|---|
| Checks live in `/tmp` scripts, not in the repo | 0 |
| App can still call upstream's servers (telemetry, feedback, kill switches) | 1 |
| Real-window behaviour: keyboard, focus, typing in pages, traffic lights, full screen, window close | 2 |
| Page features: Web Inspector, blocked popups, Little Ardia, Peek, HTTP auth, error page, tab sleep | 3 |
| Site settings, zoom per site, blocker controls, download settings, profiles, search engine choice | 4 |
| Bookmarks | 5 |
| Import from Arc and Chrome | 6 |
| Passwords | 7 |
| Extensions | 8 |

## How the code is cut (read before any step)

- The `ArdiaCore` pod (`packages/ardiacore/ios/ArdiaCore.podspec`) keeps its public headers. Chromium `.mm` files are left out of the build, never deleted.
- `packages/ardiacore/ios/webkit/` holds our native code:
  - `Standins.mm`: **generated** by `packages/ardiacore/scripts/generate-webkit-standins.py` from the public headers. Each method logs its name once as `[standin] ...`, calls completion blocks with zero values, returns `{}`. Never edit it by hand.
  - `Host.mm`, `EngineBridge.mm`, `Services.mm`, `Favicons.mm`, `Network.mm`, `Store.mm`: hand-written real implementations.
- **To implement a stand-in:** write the method in a hand-written file in `webkit/`, make the generator skip it (it already skips methods that have a real implementation; check how before adding to it), regenerate `Standins.mm`, commit both.
- `ArdiaEngineBridge call:profile:args:completion:` receives the old `ac_*` call names with JSON arguments. `EngineBridge.mm` answers the ones we support. Unknown names answer nil.
- Page-level code is Swift: `packages/ardiacore/ios/WebKit*.swift`. `WebKitTab+PageTab.swift` lists the page stubs.
- JS (`apps/browser/src`, `packages/*/src`) stays close to what upstream wrote, because every changed line is a conflict on a later rebase. Two cases:
  - **Engine work** (making a call answer): fix it in native code. A JS edit is a line or two at a platform wrapper (`apps/browser/src/platform/`) or in `state/engines/`.
  - **UI work that a step's "Do" list names** (hiding a setting, a menu item, an onboarding step, switching off an endpoint): JS edits are allowed where the UI lives. Prefer an existing `shown` predicate, constant or early return over deleting components, and touch the fewest files that do it. Update the tests that assert the removed behaviour.
  - Anything else in JS: stop and report.
- Store: one SQLite file per profile, `<data dir>/WebKit/Stores/<profile>.sqlite3`, opened by `Store.mm`. Private (incognito) profiles write nothing. New tables go in the same file. All SQL uses bound parameters.

## Rules for every step

1. **Experiment.** Take the simplest thing that works. A stand-in beats an implementation when the feature is not in the step's scope. No options, no abstraction for later.
2. **Scope.** Do the step's list. Report anything else you find, do not fix it.
3. **No Chromium.** No Chromium build, no `fetch-engine.sh`, nothing in `~/chromium-build`. No new dependencies. No deleting upstream files. No edits in `apps/linux`, `apps/ios`, `apps/site`, `apps/dashboard`, `apps/videos`.
4. **This Mac has no person at it.** The screen is often locked.
   - Launch only hidden: `open -g -n --env ARDIA_BACKGROUND=1 --env ARDIA_DATA_DIR=<scratch> ...`. Never plain `open`.
   - Never show a dialog. Never run anything that asks for a password, Touch ID or `sudo`.
   - Never read or write `~/Downloads`, `~/Documents`, `~/Desktop`. macOS asks for consent with a dialog and the call hangs. Give every instance a `downloadsDir` and a data dir in scratch.
   - Screen captures fail when locked. Use the in-process snapshots.
   - Never launch or touch `/Applications/Ardia.app`. Do not change system settings.
   - Stop every instance, server and background job you started. Never kill a process you did not start.
5. **Tools.** Node tools run as `mise exec node@24 pnpm@11.1.3 -- <command>`. CocoaPods is `/opt/homebrew/bin/pod`; clear `GEM_HOME`, `GEM_PATH` and `RUBYOPT` for it.
6. **Repo rules that apply:** no comments in code, no attribution lines in commits. The rest of the repo's `AGENTS.md` (Opus subagents, commit to `main`, releases, telemetry for new features, Bonzai, Dia parity) is the upstream owner's workflow and **does not apply**.
7. **Git.** Commit on `webkit`, small commits, imperative subjects. Never push. No PRs, no issues, nothing sent upstream.
8. **Do the work yourself.** Start no subagents.
9. **Tests.** New native logic with a branch, loop or parser gets a case in `packages/ardiacore/tests/webkit-data.test.mm` (assert-based, built with `clang++`) or a new file in the same style. JS logic gets a `.test.mjs` next to it.
10. **End of every step:**
    - Run the whole check from Step 0 (`scripts/webkit/check`). It must be as green as before the step, plus the step's new rows.
    - Rebuild the Release app and the zip at `apps/browser/build-webkit/Ardia-WebKit-Release.zip`.
    - Update `docs/webkit/standins.md` (generated by the check).
11. **Blocked?** Stop at the furthest state you can prove. Report the blocker with its output. Never weaken, skip or delete a check to pass it.
12. **Final message** (the only thing returned): result per "Done means" item with pasted output; files and commits; where this plan was wrong; what you did not check.

## Step 0. Checks in the repo

**Why:** every later step must prove it broke nothing. Today the smoke scripts are in `/tmp` and will vanish.

**Do:**

1. Create `scripts/webkit/`:
   - `build`: the Release build command (workspace `apps/browser/macos/Ardia.xcworkspace`, scheme `Ardia-macOS`, derived data `apps/browser/build-webkit`, `AdHoc.xcconfig`, through `scripts/agent/locked xcodebuild`), then the zip. Prints the app path and the zip's `shasum -a 256`.
   - `check`: runs everything below in order and prints one table (row, pass or fail, evidence). Exit code 0 only when all rows pass. Flags: `--no-build` to reuse the last build, `--only <row>` to run one row.
2. `check` rows, ported from `/tmp/ardia-webkit-release/*.mjs` and `/tmp/ardia-webkit-data/*.mjs` (copy what is needed into the repo, with the local fixture server):
   - `chromium`: the two Chromium checks print 0.
   - `sign`: `codesign --verify --deep --strict`, no entitlements.
   - `smoke-a` to `smoke-k`: the 11 smoke rows (typed URL; 5 tabs; back, forward, reload, find, zoom; `target=_blank` and `window.open`; download; second window and last-window close; quit; session restore; profile cookies; split view; content blocker).
   - `favicon`, `history`, `history-delete`, `history-private`, `search`: the data rows.
   - `native`: the `clang++` self-check `packages/ardiacore/tests/webkit-data.test.mm`.
   - `js`: `pnpm --filter @ardia/browser test` and `typecheck`. The known failure `apps/browser/src/state/telemetry/watch.test.mjs` (fixture date expired, fails on plain `v0.2.46` too) is listed by name as the only allowed failure.
3. `check` writes `docs/webkit/standins.md`: every stand-in method, grouped by class, with a mark for those hit during the run and the hit count over all launches.
4. All launches hidden, all data in a scratch dir the script creates and removes. Rows use a local fixture server, except `favicon` and `search`, which need the network: on no network they report `skipped (offline)`, never pass.

**Done means:**

- A. `scripts/webkit/check` output: the full table, all rows pass, exit code 0. Paste it.
- B. `scripts/webkit/check --no-build --only smoke-g` runs one row.
- C. Break one thing on purpose (for example, make the download settings answer an empty folder), show the row fails and the exit code is not 0, then revert. Paste both runs.
- D. `docs/webkit/standins.md` exists and lists the hit stand-ins.
- E. `git status` is clean after a run (scratch removed, nothing left in the tree).

Effort: complexity low, blast radius new scripts only, risk low.

## Step 1. Nothing talks to upstream

**Why:** this fork must not send data to the Ardia project's servers or take orders from them.

**Known endpoints** (found by grep; find the rest):

| Endpoint | What | Action |
|---|---|---|
| `https://ardia.dev/otel/v1/logs` | Telemetry | No request, ever, whatever the setting says |
| `https://ardia.dev/api/feedback` | Report a Problem | Hide the menu item and the sheet's send path |
| `https://ardia.dev/switches.json` | Remote kill switches | No fetch. Built-in defaults only |
| `https://ardia.dev/release-notes`, appcast | Updates and "what's new" | No fetch, no tab opened after launch |
| `https://services.helium.imput.net/bangs.json` | Bang list refresh | No fetch. The built-in snapshot in `packages/core/src/bangList.ts` stays |

**Do:**

1. Make each endpoint unreachable at one place (an empty URL constant or an early return at the wrapper), not by scattering checks.
2. Hide UI that only serves them: telemetry sharing toggle and "What's Sent", update channel picker, Report a Problem.
3. Onboarding: remove or skip steps that need Chromium or upstream (extension import, account-like prompts). Keep it short. First launch must reach a usable window with no dead ends.
4. Text that says "Chromium" where it is now wrong (About, engine settings pane, onboarding): fix or hide. The Engines settings pane goes away.
5. Add row `no-upstream` to `check`: run a hidden instance for 90 seconds with a fresh data dir, go through onboarding by harness, and assert no request left the app process to any host except the fixture server. Use a local HTTP proxy the app is pointed at, or the simplest equivalent that really observes requests. Web content requests (WebKit's network process) are not part of this row.

**Done means:**

- A. The list of every upstream endpoint found, with `path:line` of the place that disables it.
- B. Row `no-upstream` passes. Paste the observed request list (it should be empty or fixture only).
- C. In-process snapshots: first-launch window after onboarding, and Settings with the removed rows gone. Absolute paths.
- D. `check` all green.

Effort: complexity low, blast radius JS settings and shell wrappers, risk low.

## Step 2. The window and the keyboard

**Why:** all tests so far drove the app through the harness. Nobody has typed into it. These stand-ins decide if a person can use the window: `ArdiaChromeWindowHost` (`setTrafficLightsCenter`, `moveTrafficLightsCenter`, `windowCornerRadius`, `rootViewOfWindow`, `embeddedRootOfWindow`, `shouldCloseHandler`, `windowShouldClose`, `refusesUnhandledKeyHandler`, `userSeesWindow`, `windowFullScreenIsForPage`, `showProfile`, `prepareProfiles`, `closeWindow`), `ArdiaHost` (`quitCancelledHandler`, `menuShortcutsChanged`), `ArdiaWebView focusPage`, `ArdiaSwipe`, and `ArdiaPerformReservedKey` in `Host.mm`.

**Do:** drive a hidden instance with real key and mouse events (the repo's synthetic input: `packages/shell/ios/SyntheticInput.swift` and the dev harness; read `docs/agent-brief.md` and `docs/testing.md`). For each row below, make it work with the smallest real implementation.

| Row | Behaviour |
|---|---|
| `type-page` | Click a text input in a page, type, the input holds the text. Tab moves to the next field. Copy and paste work |
| `type-omnibox` | ⌘L focuses the command bar, typing a URL and Return loads it, Esc returns focus to the page |
| `keys-page-focus` | With focus in the page: ⌘T, ⌘W, ⌘R, ⌘F, ⌘[ and ⌘] each do their job. A page's own key handler still gets plain keys |
| `traffic-lights` | Close, minimise and zoom buttons sit where the UI asks (`setTrafficLightsCenter`), also after resize and sidebar toggle |
| `close-window` | The close button goes through the app's close policy (`shouldCloseHandler`), not straight to AppKit |
| `full-screen` | Window full screen works. A page's element full screen (a video) enters and leaves, and the UI chrome hides while it is on |
| `user-sees` | `userSeesWindow` answers true for a visible window. Find what depended on it and say what changed |
| `profile-switch` | Switching space or profile in one window shows that profile's tabs with that profile's cookies |
| `swipe` | Two-finger swipe back and forward navigates. If synthetic gestures cannot prove it, wire `allowsBackForwardNavigationGestures` and say it is unproven |
| `context-menu` | Right-click on a link and on a page shows a menu with working "open in new tab" and "copy link" (background mode logs menus instead of showing them: assert on the logged items) |

Add these rows to `check`.

**Done means:**

- A. The table, each row with evidence or the exact blocker.
- B. In-process snapshots: normal window with traffic lights, and full screen. Absolute paths.
- C. Which stand-ins got real implementations, which stay and why.
- D. `check` all green.

Effort: complexity medium, blast radius `webkit/` native files, risk medium (focus and key routing are the classic hard part). Unknown: how much hidden instances can prove about focus.

## Step 3. Page features

**Why:** `WebKitTab+PageTab.swift` still stubs page behaviours the UI uses.

**Do, in this order. Stop after the must rows if the step grows large, and report the rest:**

| Row | Need | Behaviour |
|---|---|---|
| `inspector` | Must | "Inspect" and the DevTools shortcut open Safari's Web Inspector for the page (`isInspectable` plus the simplest way to show it). Private API is acceptable here: mark it in the report |
| `popup-blocked` | Must | A popup without a user gesture is blocked and reported to the UI. `openBlockedPopup` opens it. "Always allow" persists for the site |
| `http-auth` | Must | A page behind HTTP Basic auth shows the app's credential prompt and loads after correct input. Cancel shows the 401 |
| `load-error` | Must | DNS failure, refused connection and offline show an error page with a working retry, not a blank view. The tab title and URL stay sensible |
| `page-colors` | Must | `pageBackgroundColor`, `contentsBackgroundColor`, `pageColor`: no white flash when a dark-themed space opens a tab |
| `little-ardia` | Must | A link opened from another app, with the setting on, opens the small window (`standalone`) and "open in main window" moves it |
| `peek` | Should | The Peek gesture opens the temporary page (`temporary`, `temporarySource`) and promoting it makes a normal tab |
| `tab-sleep` | Should | `discard` and `frozen`: a background tab over the budget releases its `WKWebView` and keeps URL, title, favicon and scroll-independent state. Selecting it reloads |
| `unresponsive` | Should | A page stuck in a loop gets the app's "page unresponsive" prompt, and "terminate" kills and reloads it |
| `page-cookies` | Should | `pageCookies` returns the page's cookies from its `WKWebsiteDataStore` |
| `screen-share` | Could | `getDisplayMedia` works through WebKit's own picker. No custom picker |
| `notifications` | Report only | Say what is possible with public API. Do not build |

Add the must and should rows to `check`.

**Done means:**

- A. The table with evidence per row.
- B. `WebKitTab+PageTab.swift`: the list of members still stubbed, each with a reason.
- C. `check` all green.

Effort: complexity medium, blast radius `WebKit*.swift`, risk low.

## Step 4. Site settings and browser settings

**Why:** these `ArdiaServices`, `ArdiaContentBlocker` and `ArdiaHost` calls back Settings and Site Controls. They are stand-ins, so the UI shows controls that do nothing.

**Do:**

| Row | Calls | Behaviour |
|---|---|---|
| `zoom-site` | `zoomLevels`, `setZoom` | Zoom is remembered per host and profile, applied on load, survives a relaunch |
| `site-settings` | `siteSettings`, `setSiteSetting`, `siteSettingsOrigins`, `resetSiteSettings`, `resolvePermission` | Camera, microphone, location, popups, sound: "allow" and "block" persist per origin and profile, show in Settings, and reset works. Check what `WebKitPermissions.swift` already stores and reuse it |
| `clear-site-data` | `clearSiteData` | Site Controls › Clear removes that site's cookies and storage only |
| `blocker-controls` | `ArdiaContentBlocker state`, `setEnabled`, `setList:enabled`, `isAllowedOnHost`, `setAllowed:onHost` | Global toggle, per-list toggle and per-site allow drive `WebKitContentBlocker.swift`. Site Controls shows the real blocked count |
| `download-settings` | `ac_downloads_settings` and its setter, `watchDownloadEvents`, `downloadCommand` | Choose folder and "ask where to save" persist. Pause, resume, cancel work from the downloads popover |
| `profiles` | `loadedProfiles`, `releaseProfile`, `deleteProfileData`, `isPrivateProfile`, `baseProfileOf` | Deleting a profile removes its WebKit store and its SQLite file. Closing the last private window ends that private session |
| `search-engines` | the `search.*` calls behind Settings › Search | The list offers at least Google, DuckDuckGo, Bing, Kagi and a custom URL. The choice drives typed queries and suggestions. Reuse the engine list in `packages/core/src` |
| `about` | `engineInfo` | About and `ardia://version` show the WebKit version and the app version, with no Chromium wording |

Site settings, zoom and download settings go into the profile's SQLite file. Add the rows to `check`.

**Done means:**

- A. The table with evidence per row, each including a relaunch where the row says "persist".
- B. `check` all green.

Effort: complexity medium, blast radius `webkit/` native files, risk low.

## Step 5. Bookmarks

**Why:** the bookmarks bar, the bookmark dialog and every import need `bookmarks.*`. Today it answers nil.

**Do:**

1. Read how the UI uses bookmarks: `apps/browser/src/platform/bookmarks.ts`, `packages/ardiacore/src/bookmarks.ts`, `BookmarksModule.swift`, `apps/browser/src/components/bookmarks/`. Note the exact shape of `bookmarks.tree` (`bar` and `other` roots, ids, order) and of `BookmarkOp` in `bookmarks.apply`.
2. Implement `tree`, `apply`, `watch` (the `bookmarks.changed` event), `exportHtml` on tables in the profile's SQLite file. Ids are stable across relaunch. Order is explicit.
3. `exportHtml` writes the Netscape bookmark format that browsers import.

**Rows:** `bookmark-add` (add from the UI, shows in the bar), `bookmark-folder` (folder, move, reorder, rename, delete), `bookmark-persist` (relaunch), `bookmark-export` (file parses and holds every bookmark), `bookmark-profile` (a second profile has its own tree), `bookmark-private` (a private window reads the base profile's tree, as upstream does; check and match).

**Done means:**

- A. The table with evidence. B. A native test for the op handling (add, move, reorder, delete of a folder with children). C. `check` all green.

Effort: complexity medium, blast radius `webkit/` native files, risk low.

## Step 6. Import from Arc and Chrome

**Why:** the point of this browser is to leave Arc. `packages/import` reads other browsers and writes through engine calls that are now ours.

**Do:**

1. Read `packages/import/README.md`. List every engine call the importer writes through (`history.import`, `bookmarks.apply`, `webKit.importCookies`, `ArdiaServices.savePassword`, autofill calls, and others).
2. Make each one work or answer honestly: history and bookmarks land in the SQLite store, cookies land in the profile's `WKWebsiteDataStore`. Passwords: until Step 7 exists, the importer reports "not imported", it never claims success.
3. Sources on this Mac: `~/Library/Application Support/Arc` and `~/Library/Application Support/Google`. **Copy them to scratch and import from the copy.** Never write to them. Chrome cookie decryption needs "Chrome Safe Storage" from the Keychain, which shows a dialog: do not trigger it. Use the importer's fixtures for cookies instead (`packages/import/fixtures`, `packages/import/tests`), and say that real-profile cookies were not proven.
4. Safari is out: its data needs Full Disk Access, which needs a dialog.

**Rows:** `import-arc-spaces` (Arc spaces become spaces, pinned tabs and folders keep their place), `import-arc-tabs`, `import-bookmarks` (Chrome), `import-history` (Chrome), `import-cookies` (fixture: an imported cookie is sent on the next request to the fixture server), `import-honest` (password count shows as not imported).

**Done means:**

- A. The table with evidence, including counts (spaces, tabs, bookmarks, visits) compared with the source. B. In-process snapshot of the sidebar after an Arc import. C. `check` all green. The import rows that need real profiles are marked `local-only` in `check` and skip when the source folder is missing.

Effort: complexity medium, blast radius `webkit/` native files and maybe 1 to 2 lines in `packages/import/ios`, risk medium. Unknown: how much the importer assumes Chrome profile files as its destination.

## Step 7. Passwords

**Why:** nobody uses a browser daily without passwords. WebKit pages have none today. Whether macOS offers its own Passwords autofill inside a third-party `WKWebView` was never checked, because that check needs a person at the screen. This step does not wait for it: it builds the app's own path, which upstream's UI already expects.

**Do:**

1. **Store.** Saved logins per profile: origin, username, password, created, last used, plus the "never save for this origin" list. Passwords are encrypted with one key (AES-GCM through CryptoKit, as `packages/sync` does). The key is a Keychain item named for this app. Read how the repo's test instances avoid Keychain dialogs (the mock keychain in `docs/agent-brief.md`) and use the same switch. Private profiles read, never write.
2. **Calls.** `listPasswords`, `unlockPasswords` (system authentication through `LocalAuthentication`; in background test mode it answers by the test switch, never a dialog), `password:origin:username:` (reveal), `deletePassword`, `neverSaveOrigins`, `allowSaving`, `exportPasswords` (CSV in Chrome's column layout), the `ArdiaPasswords` module's `save` and `update`, and `profileToggle` for "offer to save" and "autofill".
3. **Page side.** Extend `WebKitPageScript.swift`:
   - Detect a login form (a visible password field, the username field before it).
   - On submit or on navigation after a filled password field: send origin, username, password to native. Native emits the existing password prompt page event. `resolvePasswordPrompt` saves, updates or adds to "never".
   - Fill: when the page has a login form and the store has logins for the exact origin, offer them. Simplest UI that works: a native `NSMenu` under the focused field listing usernames; choosing one fills both fields and fires the input events frameworks listen for. One saved login and an empty form may fill on focus. Never fill a cross-origin iframe. Never fill on http when the saved origin is https.
   - The password never enters the page's JS world except as the filled field value. Use an isolated `WKContentWorld`.
4. **Import.** Step 6's `import-honest` row becomes a real password import through `savePassword`.

**Rows:** `pw-save` (submit a login on the fixture server, accept the prompt, it is listed in Settings), `pw-fill` (new session, the form fills and login succeeds), `pw-update` (changed password offers update), `pw-never`, `pw-two-accounts` (menu lists both), `pw-origin` (a different origin and an http downgrade get nothing), `pw-private` (no save), `pw-export`, `pw-relaunch`, `pw-at-rest` (the SQLite file does not contain the plaintext password: `grep` proves it).

**Done means:**

- A. The table with evidence. B. Native tests: encryption round trip, origin matching (scheme, host, port; no subdomain match), form detection on 5 fixture forms (plain, username on a previous page, sign-up form with two password fields that must not fill, form inside an iframe, form built by script after load). C. `check` all green.

**Known limit to report, not solve:** the app is ad hoc signed, so each new build is a new identity to the Keychain. A person will see one "allow access" dialog per build. The fix is a stable signing identity, which needs the owner.

Effort: complexity high, blast radius page script plus `webkit/` native files, risk high (security-sensitive). The orchestrator gets a separate review of this step before it is accepted.

## Step 8. Extensions

**Why:** uBlock-class blocking is covered by the built-in blocker, but a password manager extension and others matter for daily use. Chrome's extension system is gone. WebKit has `WKWebExtensionController` (macOS 15.4+).

**Gate first.** Before any UI work, prove three things in a hidden instance and report. If one fails, stop the step there.

1. An unpacked Manifest V3 extension with a content script loads through `WKWebExtensionController` and its script changes a fixture page.
2. Its background service worker receives a message from the content script and answers.
3. Its toolbar action popup page can be shown in a view the app controls.

**Then:**

| Row | Calls | Behaviour |
|---|---|---|
| `ext-install-folder` | `inspectUnpacked`, `installExtension` | Install from a folder, per profile. Listed in Settings |
| `ext-install-crx` | `installCrx` | A `.crx` file unpacks (CRX3 header, then zip) and installs. Reuse `ArdiaExtensionPackage.mm` if it is engine-free |
| `ext-toggle` | `setExtension:enabled:`, `uninstallExtension`, `reloadExtension`, `listExtensions` | Enable, disable, remove, reload; state survives a relaunch |
| `ext-action` | `actionStates`, `executeExtensionAction`, the action popup events | The toolbar shows the action with icon and badge; a click opens the popup in the app's existing popup UI |
| `ext-tabs-api` | the `WKWebExtensionTab` and `WKWebExtensionWindow` protocols | `tabs.query`, `tabs.create`, `tabs.update`, `tabs.onUpdated` reflect the app's real tabs and windows |
| `ext-permissions` | install prompt | Host permissions are asked once at install through the app's install dialog |
| `ext-store` | Web Store page | Report only: what it takes to make "Add to Chrome" on the Chrome Web Store install here. Do not build |

Test extensions: write two tiny fixtures in the repo (content script plus action popup; tabs API user). Then try uBlock Origin Lite and one password manager's unpacked build from their public release archives, and report what works. Their failure does not fail the step.

**Done means:**

- A. The gate results. B. The table with evidence. C. The list of extension APIs that the two real extensions asked for and WebKit refused. D. `check` all green.

Effort: complexity high, blast radius new native files plus the extension UI wrappers, risk high. Unknown: how well Chrome extensions run on WebKit's implementation.

## Not planned

Each of these is its own decision after the steps above.

- Address and card autofill.
- Sync and the iPhone companion on the new stores.
- Web notifications, Cast, WebBluetooth, WebUSB.
- The `ardia` command's control of tabs (it used Chromium's debugging protocol).
- Passkeys (need an entitlement Apple grants per app).
- A stable signing identity and notarisation.
- Rebase onto a newer upstream tag. The branch is on `v0.2.46`. When it is time: rebase, regenerate `Standins.mm`, fix the compile errors, run `check`.
- Native UI instead of React Native ([proposal](proposal.md#phase-3-evolve-to-native-ui)).

## Progress

| Step | State | Commits | Notes |
|---|---|---|---|
| 0. Checks in the repo | complete | `5722bc3cc` | 20 rows pass; verified without old scratch folders; intentional failure detected. |
| 1. Nothing talks to upstream | blocked | `45bedc4d5` | Release rebuilt; 20 baseline rows pass. Privacy crashes in the unchanged content-blocker stand-in before the new request check reaches 90 seconds. |
| 2. Window and keyboard | not started | | |
| 3. Page features | not started | | |
| 4. Site and browser settings | not started | | |
| 5. Bookmarks | not started | | |
| 6. Import | not started | | |
| 7. Passwords | not started | | |
| 8. Extensions | not started | | |
