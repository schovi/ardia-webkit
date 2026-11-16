# Plan: replace Chromium with WebKit

Status: **accepted**, 2026-11-16. Decisions: cut first, permanent GitHub fork, simplest approach because this is an experiment. Based on upstream Ardia `eb217182` (see [learnings](learnings.md#upstream-on-2026-11-16)).

Scope: the engine replacement only. The result is a working browser with no Chromium in the app. Extensions, native UI and other gaps come after.

## What changed the plan

The first proposal assumed that every Ardia tab is a Chromium tab. That is no longer true.

- Upstream ships a **WebKit page engine** next to Chromium since 2026-10-24. It exists to play DRM video
- A setting picks the default engine for all tabs: `pageEngine: "chromium" | "webkit"` (Settings › Engines)
- Native code already has the seam: protocols `PageTab` and `PageEngine`, with a Chromium and a WebKit implementation each (`packages/ardiacore/ios/PageTab.swift`, `PageEngine.swift`)
- `WebKitTab` and its helpers are 24 Swift files, about 3,300 lines. They cover navigation, downloads, permissions, content blocking, find, popups, PiP, per-profile data stores and private sessions

So the page layer is mostly done. The work is everything Chromium still does around the pages.

## What Chromium still does

| Chromium job today | WebKit replacement | State |
|---|---|---|
| Runs the process. `main.swift` calls `ArdiaHost.run`, which starts `ChromeMain` | Plain `NSApplication` run loop | Build. Small |
| Owns each window (`ArdiaCoreWindow`, a Chrome Views window) | Plain `NSWindow`. `WindowManager.swift` already falls back to `BrowserWindow` when the Chrome host returns nil | Build. Check in the spike |
| Renders tabs (`ArdiaWebView`) | `WebKitTab` | Exists. About 20 `PageTab` members are stubs |
| History, bookmarks, favicons, search engines, zoom, site settings, download settings (Chrome services behind 72 `ac_*` calls) | Native stores, one per profile | Build |
| Passwords and autofill (Chrome's stores and dropdowns) | Own store plus a page script, or a password-manager extension | Build. Unknown |
| Extensions (Chrome's system, Web Store installs) | `WKWebExtensionController` | Build. Hard. After the first version |
| Content blocker (uBlock Origin as a Chrome component extension) | `WKContentRuleList` from uBlock Origin Lite rules (`WebKitContentBlocker.swift`) | Exists |
| DRM video in Chromium (FairPlay bridge, native players, mirrored controls) | Not needed. WebKit plays FairPlay itself | Leave out of the build |
| Internal pages (`ardia://history`, `version`, `flags`, `gpu`), which are Chrome's own pages | Own page for history. Drop the rest | Build one, drop four |
| Cast, Bluetooth and USB choosers, tracing, task manager, `ardia` CLI control over CDP | No WebKit equivalent | Stand-in (feature off) |

## Decision

**Cut Chromium out first, answer every missing call with a stand-in, then fill the gaps in order of daily use.** This is an experiment, so each step takes the simplest thing that works.

Options considered:

| Option | Gain | Cost |
|---|---|---|
| **A. Cut first, stand-ins, fill** (chosen) | Answers the biggest unknown on day one: does the UI run with no Chrome under it. Fast builds, no engine download. Same method upstream used for Windows (`docs/windows.md`, "Calls Windows still answers with a stand-in") | The app lacks history and passwords for the first steps |
| B. Keep Chromium running, move services off it one by one, remove it last | The app works at every step | Boot and windows, the riskiest part, land last as one big change. Every moved service must live next to Chrome's version |
| C. New package `packages/webkitcore` with a copied JS API (first proposal) | Clean separation | Duplicates 163 typed calls and the WebKit Swift files that upstream keeps changing |

### Where to cut

The cut is at the native symbol level, inside the `ArdiaCore` pod. JS stays as it is.

- `packages/shell` and the Swift Expo modules call ObjC classes: `ArdiaHost`, `ArdiaServices`, `ArdiaChromeWindowHost`, `ArdiaWebView`, `ArdiaEngineBridge`. About 220 public methods
- Those classes are implemented in `.mm` files on top of Chromium (`ArdiaCore.h` and the `ac_*` calls)
- **WebKit flavor of the pod:** same module name, same public headers, different implementation files. The Chromium `.mm` files are left out of the build. New Swift files implement the same classes on WebKit and AppKit, or return a stand-in
- One build variable selects the flavor (for example `ARDIA_ENGINE=webkit`, read by the podspec)

Why this line: `packages/shell` (16 files use engine classes), the Swift modules and all TypeScript compile unchanged. An upstream change to a public header shows up as a compile error in our files. That error list is the sync to-do list.

This design comes from reading headers and file lists. Nothing was compiled yet. Step 2 proves or breaks it.

## First working version: what is in

| In | Out (stand-in, feature hidden) |
|---|---|
| Windows, sidebar, spaces, profiles, tabs, pins, splits | Extensions |
| Omnibox with suggestions, navigation, find, zoom | Address and card autofill |
| Downloads, permission prompts, content blocking | Cast, Bluetooth and USB choosers |
| History, bookmarks, favicons, session restore | Web notifications, page translation |
| Arc import (spaces, tabs, bookmarks, cookies) | `ardia` CLI control, tracing, task manager |
| Passwords (form decided in Step 2b) | Passkeys (need an entitlement that Apple grants per app) |

## Steps

### Now

**Step 0. Baseline with the stock app. No code.**

1. Install the current Ardia release
2. Set Settings › Engines › default engine to WebKit
3. Browse for a day. Write down every page-level gap

Done when: `docs/webkit-gaps.md` lists the gaps seen in real use.
Effort: none. This replaces guessing which `WebKitTab` stubs matter.

**Step 1. Fork and toolchain.**

1. Fork `mantrakp04/ardia` on GitHub. Branch `webkit` from the latest stable tag `v0.2.46`. Done
2. Move these docs into the fork (`docs/webkit/`). Done
3. Install the toolchain: Node 24, pnpm 11, CocoaPods

A stock Chromium build is skipped. Build it only if the spike fails for a reason that looks like toolchain.

**Step 2. Spike: boot with no Chromium.** Throwaway branch.

1. Add the WebKit flavor to the podspec. Leave every Chromium `.mm` file out
2. `ArdiaHost.run` starts a plain `NSApplication` and the React Native host
3. Generate a stand-in for every public method the linker asks for. Each one logs its name once
4. Window is the plain `BrowserWindow`. Every tab uses the `ArdiaWebKit` view

Done when: a hidden instance shows the sidebar and loads a page, and `otool -L` shows no `Chromium Framework`.
Output: the gap table, one row per missing method and call: `webkit`, `stand-in` or `missing`.
Effort: complexity medium, blast radius one pod, risk medium. This step answers the main unknown: how much of the shell and UI needs real Chromium objects.

**Step 2 result (2026-11-16): done.** Commits `529b517e4` and `db5a01dc6`.

- Debug build succeeds with no Chromium framework linked or embedded. App size is 65 MB
- A hidden instance loads `https://example.com` in a WebKit tab. The sidebar, toolbar and page render
- `packages/shell` needed **no changes**. The plain-window fallback in `WindowManager.swift` works as is
- The cut is 3 new files: `packages/ardiacore/ios/webkit/Standins.mm` (generated, 1,557 lines), `webkit/Host.mm` (45 lines, hand-written) and the generator script. The podspec lists 7 engine-free `.mm` files to keep
- Boot and one page load hit 36 stand-ins. Most are window chrome, tab strip and page-input settings
- JS edits: `engines.ts` returns `webkit` for every tab, and the `pageEngine` default is `webkit`
- Open: 24 of 2,271 JS tests fail. Most assert that Chromium is chosen. Not triaged yet

**Step 2b. Spike: passwords and extensions in `WKWebView`.** Runs next to Step 2, in the same throwaway app.

1. Log in to a site. Check if iCloud Keychain or 1Password autofill appears
2. Load unpacked uBlock Origin Lite and 1Password through `WKWebExtensionController`

Done when: both answers are written in learnings. They decide the form of Step 6 and the size of the extensions work.

### Then

**Step 3. Make the flavor real.**

- Stand-in table checked in, like upstream's `forwarded.json` for Windows
- Window host: traffic lights, full screen, profile paging, launch picture, quit flow
- JS: one flavor entry in `PLATFORM_FEATURES`, default engine `webkit`, engine chooser and Chromium-only rows hidden

Done when: windows, spaces, tabs, splits, omnibox and session restore work in a hidden instance, and upstream's JS tests pass.
Effort: complexity medium, blast radius pod plus about 5 shared TS files, risk medium.

**Step 4. Page parity.** Fill the `WebKitTab` stubs that Step 0 showed matter. Expected: blocked popups, Web Inspector, Little Ardia and Peek pages (`standalone`, `temporary`), warm and neighbour tabs, tab sleep (close the `WKWebView`, keep URL and title), unresponsive pages, screen sharing. Add the own `ardia://history` page.

Done when: the Step 0 gap list is empty or each open row has a written reason.
Effort: complexity medium, blast radius `WebKit*.swift`, risk low.

**Step 5. Browser data off Chrome.** Native stores behind the existing `call("domain.verb")` names: `history.*`, `bookmarks.*`, `favicons.*`, `search.*`, `sites.*` (zoom, settings), `downloads.settings`, `profiles.*`, clear browsing data. Then run the Arc import end to end, because it writes through these calls.

Reuse first: the iPhone app's Swift package `apps/ios/Packages/ArdiaKit` builds for macOS 27 and holds history, tab and blocking code on WebKit. Check what fits before writing new stores.

Done when: history, bookmarks and favicons survive a relaunch, and an Arc import shows spaces, tabs and bookmarks.
Effort: complexity medium, blast radius new Swift files only, risk low.

**Step 6. Passwords.** Form depends on Step 2b:

| Step 2b result | Step 6 |
|---|---|
| System autofill works in `WKWebView` | Wire it up. Small |
| Only the extension works | Extensions move up, before this step |
| Neither works | Own store in the Keychain, a page script for login forms, and the fill and save prompts. Ardia's password UI already exists and stays |

Done when: one week of daily use without opening another browser. That is the first working version.

### Later, each as its own decision

- Extensions (`WKWebExtensionController`, install from the Chrome Web Store)
- Address and card autofill
- Sync and iPhone companion check on the new stores
- Memory saver, web notifications, CLI control
- Native UI (Phase 3 in the [proposal](proposal.md#phase-3-evolve-to-native-ui))

## Fork and upstream sync

Upstream moved 3,683 commits in 24 days and takes only bug fixes from outside contributors (`CONTRIBUTING.md`). A WebKit flavor counts as a feature. Ask the owner on Discord, but plan for a permanent fork.

Rules that keep each rebase cheap:

1. **Add files, do not edit shared ones.** Upstream ports Linux and Windows the same way
2. **Leave Chromium files out of the build, do not delete them.** A deleted file that upstream edits is a conflict on every rebase
3. **Follow stable tags, not `main`.** Nightlies churn
4. **Treat compile errors in our flavor as the sync list.** No separate tracking

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Shell or UI needs Chromium objects beyond the public headers | Step 3 grows | Step 2 shows it before any real work |
| Upstream changes public headers often | Flavor breaks on each sync | Stable tags. Stand-ins are generated, not hand-written |
| No password autofill in `WKWebView` | Own password manager needed | Step 2b decides early. UI and store design already exist upstream |
| WebKit has no public API for web notifications, WebBluetooth, WebUSB, Widevine | Some sites lose features | Accept. List them in the gap doc |
| Sites that sniff for Chrome | Broken pages | Upstream already sends Safari's user agent on WebKit pages. Watch in Step 0 |

Licence: upstream's `NOTICE` says the app is GPL-3.0 only because its engine carries Helium's patches, and Ardia's own source is Apache-2.0. A build with no Chromium drops that reason. Check the licence of the uBlock Origin Lite rules before any distribution.

## Open decisions

1. **Passwords in the first version:** decided by Step 2b, not now
