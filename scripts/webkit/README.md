# WebKit checks

Run from this checkout on an Apple Silicon Mac with Xcode. The entry points select Node 24 and pnpm 11.1.3 through `mise`.

## Build

For a checkout without installed packages or Pods:

```sh
mise exec node@24 pnpm@11.1.3 -- pnpm install
(cd apps/browser/macos && mise exec node@24 pnpm@11.1.3 -- ../../../scripts/agent/locked pod -- env -u GEM_HOME -u GEM_PATH -u RUBYOPT LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 /opt/homebrew/bin/pod install)
```

Run `pod install` from inside `apps/browser/macos`, as above: with `--project-directory` it fails at `use_native_modules!`. Run it again after you add or remove a native source file.

```sh
scripts/webkit/build
scripts/webkit/check
```

`build` runs Release through the Xcode lock, bundles JS, signs ad hoc, and replaces `apps/browser/build-webkit/Ardia-WebKit-Release.zip`. It prints the app path and SHA-256. Its log is `apps/browser/build-webkit/build-webkit.log`.

`check` rebuilds by default. It prints one result table and exits nonzero for FAIL or offline results. `NEEDS PERSON`, `SKIPPED (screen locked)` and `SKIPPED (no key window)` (the session is unlocked but AppKit does not grant a key window) never count as passes and do not affect the exit code. It removes its scratch folder, downloads, snapshots, logs, fixture server, and app instances, including after a failed row. The `no-upstream` row keeps copies of its evidence in `apps/browser/build-webkit/step-1-evidence/`.

## Run one row

```sh
scripts/webkit/check --no-build --only smoke-g
scripts/webkit/check --help
```

Each row starts with fresh data. Rows that test persistence relaunch on their own data directory. No row depends on another row or an old `/tmp` folder.

`favicon` uses Python.org. `search` uses Google. A failed network preflight reports `skipped (offline)` and exits nonzero. A native failure after successful preflight fails the row.

`js` runs the script tests, the browser suite, and typecheck. It permits only the named, expired-date fixture in `src/state/telemetry/watch.test.mjs`. It rejects other failures, missing totals, cancelled tests, and skipped tests.

Every run regenerates `docs/webkit/standins.md` for its selected rows. Counts describe logged hits over all launches, not invocation counts. Run the full check before committing that report; a single-row run has different coverage.

## Tour Settings

`settings-tour` reads the available pane list from the app and opens every pane with advanced settings enabled. It captures each pane's own native root, not the surrounding window. A missing root, uniform image, app exit, or logged JS exception fails the row. Caught exceptions and startup exceptions count too.

The row keeps per-pane PNGs and logs plus `results.json` in `apps/browser/build-webkit/settings-tour-evidence/`. It continues after failures to report all panes. A crash starts another hidden instance for the remaining panes, but the row still fails.

The native check tests empty blocker responses, real list metadata, blocked counts, placeholder replies, pane-root lookup, and blank-image rejection. `smoke-k` compares the settings response with the real WebKit blocker and its blocked count.

The harness points sync and shared folders at scratch paths. The tour opens panes only; it does not press setting controls, unlock passwords, or show dialogs.

## Observe app requests

`no-upstream` leaves onboarding incomplete and seeds telemetry sharing as enabled. It finishes the appearance screen through the harness, loads a fixture page, opens General and Privacy settings, and observes at least 90 seconds from launch through quit.

`ARDIA_TEST=networkRequests` inserts a passive `NSURLProtocol` into session configurations before the app starts. A test-only replacement of the `protocolClasses` getter covers default, ephemeral, and shared sessions. It appends HTTP and HTTPS requests to `<data>/requests.jsonl`, with the app PID. It returns false so normal networking continues. WebKit's separate network process does not load this observer.

The row requires a JS `fetch` and a native search request to reach the fixture and appear in the observation. It then rejects every observed origin except the fixture. A missing observer fails the row. This covers the app's URL Loading System, not arbitrary raw sockets or other processes.

The row retains `requests.json`, `after-onboarding.png`, `settings-general.png`, and `settings-privacy.png` in the evidence directory. Its scratch directory and app still get removed. `browser.snapshot(name, windowNumber)` selects a specific native window when Settings is open.

## Add a row

Add a function to `rows` in `rows.mjs`, returning a short evidence string. Throw an assertion error on failure. Rows receive `browser`, `fixture`, and `scratch`. New rows start a browser by default; add nonbrowser rows to the exclusion list in `browserRows`. Use the local fixture in `fixture.mjs` for page content. Add JS helper cases to `check.test.mjs`.

Use `browser.open`, `activate`, `page`, `execute`, `type`, `until`, and `restart`. `page` runs in WebKit's isolated script world; DOM state is shared. `execute` runs in the page's world. Check the resulting page or state, not only whether the call returned.

The blocker row uses a local script path matching the bundled EasyList `\.ar/ads/` rule. A control script must load, the blocked count must rise, and the server must receive no ad request.

## How the harness reaches Release

Chromium's CDP listener is absent. `Browser.launch()` uses hidden `open -g -n`, a fresh `ARDIA_DATA_DIR`, `ARDIA_BACKGROUND=1`, the file keychain, and `ARDIA_INSTANCE=downloadsDir=<scratch>/downloads`.

An empty `<data>/perf-probe` file must exist **before launch**. In an isolated Release instance it enables `startDevHarness` and the omnibox drivers. `onboarding.json` marks setup complete.

`Browser` reuses `scripts/lib/instance.mjs`: `app.eval(body)` writes an identified `dev-eval.js` file under the data directory. The app reads it and writes `dev-eval-result.json`. The body receives `ac` and must return its result or promise. `app.ready()` retries because the watcher ignores the script present when it starts. Native calls such as `ac.shell.windowIds()` return promises. The command bar uses the hero driver on a New Tab page and the panel driver on a loaded page. Select the registered driver for the window instead of assuming `:panel`.

WebKit evaluation must answer through `post("result", JSON.stringify(value))`. `browser.page(id, expression)` supplies that protocol. All polls have deadlines and fail if the app dies.

## Take an in-process snapshot

The Release shell snapshot module is absent. The existing `windows.list` and `windows.dev` engine calls work instead. `browser.snapshot()` finds a native window with `hasRoot`, sends `snapshotFrame:<path>`, and verifies the PNG. The path must stay inside that instance's data directory.

This standalone example keeps the scratch directory so you can inspect the PNG. It stops the app and server. Remove the printed directory after inspection.

```sh
mise exec node@24 pnpm@11.1.3 -- node --input-type=module <<'NODE'
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Browser } from './scripts/webkit/support.mjs';
import { startFixture } from './scripts/webkit/fixture.mjs';
const data = mkdtempSync(join(tmpdir(), 'ardia-webkit-snapshot-'));
const fixture = await startFixture();
const browser = new Browser(data, fixture, []);
try {
  await browser.launch();
  await browser.open('/first');
  await browser.snapshot();
  console.log(join(data, 'window.png'));
} finally {
  try { await browser.stop(); } finally { await fixture.close(); }
}
NODE
```

Snapshots render the app's layers without WindowServer. They work while the screen is locked. Foreground rows provide active/key-window evidence. Captures alone do not prove physical input.

## Window and keyboard checks

Step 2 adds `type-page`, `type-omnibox`, `keys-page-focus`, `traffic-lights`, `close-window`, `full-screen`, `user-sees`, `profile-switch`, `swipe`, and `context-menu`.

`type-page`, `type-omnibox`, `keys-page-focus`, `full-screen`, and `inspector` use foreground mode on this unattended Mac. Each launch first reads `ioreg -n Root -d1 -a`; a true `CGSSessionScreenIsLocked` reports `SKIPPED (screen locked)`. Missing or false means unlocked. A lock file enforces one foreground instance at a time. Other Step 2 rows stay hidden.

Foreground launches use `open -n` with normal activation and no `ARDIA_BACKGROUND`. After the harness starts, an AppKit timer activates the app and orders its window key. The row reports `SKIPPED (no key window)` if AppKit does not grant a key window; it never substitutes fake foreground state. They keep scratch data, downloads, sync/shared folders, the file keychain, and the harness probe. Input stays inside the app through AppKit events and responder calls. Checks never use `CGEventPost`, `osascript`, System Events, Accessibility, or `screencapture`. Camera, microphone, location, screen recording, protected folders, and the real Keychain stay out of these rows.

A native watchdog records app-modal alert text in `modal-alert.json`, dismisses the alert, and quits. The row fails with that text. Cleanup requests quit through the test-only `windows.devQuit` call, including hidden instances and the quit smoke row. Its run-loop timer avoids blocking the main dispatch queue while AppKit waits for the asynchronous save reply.

`swipe` verifies `allowsBackForwardNavigationGestures` and reports `NEEDS PERSON`: synthetic input cannot prove real trackpad recognition. Assertion failures remain FAIL. When any row reports `NEEDS PERSON` or `SKIPPED`, the check prints the path to `docs/webkit/needs-person.md`.

`inspector` requires a connected frontend in a visible native window, with a loaded URL and positive dimensions. It checks Inspect selection mode, detaches the frontend, captures that window, closes it, and reopens it through queued Option+Command+I. Test-only `webKit.devInspector` reads private `_inspector` state and its `inspectorWebView`; its `detach` and `close` actions affect only that inspector. The capture stays in `step-2-evidence/inspector.png`.

The Release `windows.dev` hook accepts `activate` (foreground only), `state`, `menus`, `key:<characters>|<keyCode>|<modifierFlags>`, `hardwareKey:<keyCode>|<modifierFlags>`, `mouse:<down|up|rightdown|rightup>,<x>,<y>`, `resize:<width>,<height>`, `close`, and `fullscreen`. Mouse coordinates start at the window's top left. These hooks require an isolated test instance. `state` returns first responder, page frames, gesture settings, traffic-light centers, visibility, and the last full-screen notification. `menus` reports enabled key equivalents after validation. Both key hooks post down/up events to the app’s own event queue. This preserves `NSApp.currentEvent`, which React Native needs for Esc. Shortcut checks use `hardwareKey`, matching the current keyboard layout. On a Czech layout, the physical bracket keys produce `ú` and `)`. Creating these local events does not post input to another process. The test-only `webKit.devPageState` call reports actual page focus, focus-request count, active/key state, and WebKit full-screen state.

The background app keeps an internal key-window reference without making a real window key. It never activates the app. Window full screen sends AppKit notifications and changes the frame without creating a Space. Foreground windows use AppKit's full-screen implementation. WebKit's `fullscreenState` updates the page's full-screen event and the host's page-full-screen flag. The row waits for `didEnterFullScreen` / `didExitFullScreen` and visible occlusion state before its next action. JS window state changes at the earlier `will` notification. Test instances log both window notifications and WebKit state transitions. The row retains `step-2-evidence/fullscreen.log` and records trusted-click or request-rejection evidence on failure.

Background WebKit menus write `context-menu.json`. A title in `context-menu.json.pick` selects an enabled item through its native action. The app logs and dismisses the menu. The context-menu row verifies the new tab, copied URL, and separate page menu.

Window rows retain `normal.png` and `fullscreen.png` in `apps/browser/build-webkit/step-2-evidence/`. Frame snapshots render the titlebar and cache traffic buttons separately because those buttons need not have layers. The native row also builds `packages/ardiacore/tests/webkit-window.test.mm` with AppKit, WebKit, and QuartzCore.

## Site and browser settings

Step 4 adds `zoom-site`, `site-settings`, `clear-site-data`, `blocker-controls`, `download-settings`, `profiles`, `search-engines`, and `about`.

Settings rows use the local fixture. Persistence rows relaunch on the same scratch data. `site-settings` sends a test message from a real WebKit frame into the media permission delegate. The test never calls `getUserMedia` or geolocation. Location coverage stops at storage and the Settings response.

`download-settings` uses a slow fixture with Range support for pause, resume, and cancel. Background mode logs the save-panel request and uses the configured scratch folder. A person must verify the actual picker. The About test invokes the native menu action; background mode logs its versions instead of opening a panel.

The native row links `Store.mm` into the Swift page self-check through the public settings declarations. Popup migration and private grants therefore use the actual SQLite implementation.

## Bookmarks

Step 5 adds `bookmark-add`, `bookmark-folder`, `bookmark-persist`, `bookmark-export`, `bookmark-profile`, and `bookmark-private`.

The rows drive the existing command, dialog button, store actions, and mounted components through the harness. Reorder uses `moveBookmark`, the action called by drag completion. Physical drag recognition remains in `docs/webkit/needs-person.md`.

`bookmark-persist` removes the JS bookmark cache before relaunch and checks the profile SQLite file. It retains `apps/browser/build-webkit/step-5-evidence/bookmarks-bar.png`.

Background `bookmarks.exportHtml` bypasses the save panel and writes `<data>/WebKit/Bookmarks.html`. The row parses the file with the real import module. Foreground export still uses the save panel.

Chromium suppresses `bookmarks.changed` during `apply`. The watcher row checks this and the initial model-load event with `{profile}`. UI edits already update the JS store before saving.

## Import

Step 6 adds six fixture rows: `import-arc-spaces`, `import-arc-tabs`, `import-bookmarks`, `import-history`, `import-cookies`, and `import-honest`.

The wizard's `acImport` handle works in Release only for an isolated test instance. Hermes evaluation needs promise chains; it cannot parse async functions.

`import-arc-local` and `import-chrome-local` are local-only. Each copies importer inputs into scratch before discovery or import. Copies exclude cookies, passwords, autofill, caches, sessions, and blobs. Neither row unlocks a source browser. A missing folder or a folder without an importer-readable profile reports `SKIPPED (no source profile)`, never PASS. This status does not affect the exit code.

The Arc rows compare space and tab counts, relative pin and folder order, folder membership, and theme presence. Split folders become split views. The Chrome rows compare bookmark nesting/order and history titles, last visits, and aggregate visit counts, then relaunch. History stores the aggregate count and the last known visit, without inventing individual visit times.

`import-cookies` uses the existing invented Chrome fixture and `ARDIA_TEST=importSecret`. It proves private-profile rejection and an imported session cookie on the next server request. It never requests another browser's Keychain item. Passwords import through `savePassword`. Addresses and cards stay hidden, with zero imported counts and explicit result text. The password fixture includes an Android credential. The check proves its rejection and the saved count for every supported web credential.

Arc snapshots stay in `apps/browser/build-webkit/step-6-evidence/`. Real source data and detailed errors stay in scratch. The rows delete source copies even if stopping the test instance fails. Copy-removal output includes a directory listing. A usable real source also checks its strings against the patch with `grep -F -f`, without printing matching data.

## Passwords

Step 7 adds `pw-save`, `pw-fill`, `pw-update`, `pw-never`, `pw-two-accounts`, `pw-origin`, `pw-private`, `pw-export`, `pw-relaunch`, and `pw-at-rest`.

Each instance uses the existing `FileKeyStore` abstraction. The launch helper sets `ARDIA_TEST=keychain=file,reauth=granted`. Set its `reauth` option to `denied` to test refused unlocks. Every isolated instance uses the file backend, even without the keychain switch. Background and isolated instances never evaluate LocalAuthentication. Background instances without an isolated directory refuse access to password keys.

Normal instances use `KeychainKeyStore(service: "Ardia WebKit Passwords")`. `WebKitPasswordKeyStore.swift` links to the existing sync key-store source. Each data directory has one 256-bit key. The profile SQLite files hold AES-GCM ciphertext and public login metadata. Authentication binds ciphertext to its profile, origin, and username. A missing key never replaces a key for existing records. A nonblocking file lock serializes key creation across processes.

Password detection and fill use the dedicated `ardia.passwords` content world and `ardiaPasswords` message handler. The ordinary `browser.page` helper cannot access that world. Test-only `webKit.devPasswordFocus` focuses a field there and exercises the native chooser. Its `subframe` flag selects an actual recorded WebKit frame. Its `probe` flag returns only whether the password field is empty. These hooks require an isolated test instance.

Background menus write `password-menu.json`. A username in `password-menu.json.pick` selects that native menu action. The menu file contains usernames and enabled flags, never passwords. Foreground placement, physical typing, Touch ID, and ad hoc Keychain access remain person checks.

Forms submit through the page world, with fixture values assigned before `requestSubmit()`. Fill checks inspect shared DOM values and authenticate against the fixture server. Fixtures cover two-step login, dynamic forms, signup, hidden fields, same-origin and cross-origin frames, and a hostile page. The hostile page records whether its own world can access either native handler or the isolated API. The server never records submitted passwords.

`webKit.devPasswordExport` supplies a caller-chosen scratch path. Background export without a path cancels. The export row checks mode 0600, parses the Chrome CSV with the real importer, and verifies refused authentication writes nothing. `webKit.devPasswordBridge` verifies mutable input wiping and explicit unsupported password sync replies. These calls exist only in test instances.

The native row runs `webkit-passwords.test.swift`: encryption round trip, tampering, authenticated metadata, key reuse/isolation/loss, exact origins, updates, exceptions, CSV permissions, symlink handling, hex parsing, and five actual WebKit form fixtures. `pw-at-rest` runs `grep -a -l -F` against SQLite and its sidecars. A match prints only the filename. No HTTPS fixture runs: the native origin cases and a stored HTTPS login presented to an HTTP page prove downgrade rejection without certificate dialogs.

## Extensions

Step 8 adds `ext-gate`, `ext-install-folder`, `ext-install-crx`, `ext-toggle`, `ext-action`, `ext-tabs-api`, and `ext-permissions`.

The gate loads the committed Manifest V3 fixture through a temporary controller inside a hidden app instance. It checks shared DOM changes, a service-worker reply, and the framework-owned popup attached to an app-owned view. The install prompt uses `extensions.installPrompt` and the existing `extensions.resolveInstallPrompt` call. The gate grants nothing before acceptance.

The production rows install managed copies under `<data>/WebKit/Extensions/<profile UUID>/<Chrome id>`. SQLite profile settings hold metadata, enabled state, and accepted permissions. Background install prompts log to `<data>/WebKit/extension-install-prompt.json`. Declining removes the pending copy. Private windows attach no extension controller. File-page access stays blocked. Extension sync returns `ready: false` or `state: refused`, with `unsupported: true`.

The action row runs in foreground mode. It invokes the mounted toolbar handler, then uses native in-app mouse events to close and reopen the popup. It requires an active app, a key and visible window, positive popup dimensions, and visible ancestor opacity. The existing popup UI hosts `WKWebExtension.Action.popupWebView`. Test-only `webKit.devExtensionPopup` checks attachment and reads its DOM without requiring a key window. `extension-content` checks that its content world cannot access `ardiaPasswords` or `__ardiaPasswords`. `extension-tabs` checks real query, creation, navigation, and update events.

The native row checks CRX3 bounds and identifiers, rejected symbolic links, and rejected ZIP traversal. CRX extraction uses the system Python `zipfile` module, with a 30-second process deadline. It validates archive entries before extraction. Local and store CRX files require authenticated RSA-SHA256 or ECDSA-SHA256 proofs matching their signed ids before extraction. Installation still requires explicit consent. Automatic extension updates remain unsupported.

`apps/browser/build-webkit/step-8-evidence/` retains Settings and popup snapshots. Physical input, popup focus, Esc dismissal, and appearance remain person checks. Native mouse dismissal and reopening are automated. The two real release archives are manual compatibility probes, not dependencies of the repeatable check.

`ext-store` is a network row. It loads the real uBOL detail page, checks the enabled button, rejects a forged nonce, and invokes the isolated test click hook. It accepts the logged prompt through `extensions.resolveInstallPrompt`, verifies the requested id and Added state after relaunch, then declines a second installation and checks cleanup. Offline preflight returns `skipped (offline)`. `ext-store-origin` proves local main-frame and subframe rejection and absence of the handler in the page world. `webKit.devExtensionStore` runs only in test instances and evaluates inside the dedicated store world. Production clicks require `isTrusted` and a one-use nonce.
