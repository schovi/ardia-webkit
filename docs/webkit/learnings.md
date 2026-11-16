# Learnings

Collected 2026-10-22 to 2026-10-27. Ardia numbers are from commit `ca5c19b0` (2026-10-23), except the first section.

## Upstream on 2026-11-16

Upstream `main` at commit `eb217182`. The Ardia sections further down describe `ca5c19b0` and are partly out of date. This section wins where they differ.

### Size and pace

| Metric | 2026-10-23 | 2026-11-16 |
|---|---|---|
| Commits | 1,522 | 5,205 (3,683 new, 6,437 files changed) |
| Authors | 1 | 10+ |
| UI, `apps/browser/src` (no tests) | 332 files, ~51k lines | 1,200 files, ~110k lines |
| Native engine modules, `packages/ardiacore/ios` | part of ~32k | 203 files, ~32k lines |
| Native shell, `packages/shell/ios` | | 185 files, ~17k lines |
| Chromium-side code, `engine/chromium` + `engine/ardiacore` | | ~36k lines |

- Engine is Chromium 157 on Helium 0.21.2. CEF left the tree on 2026-10-09
- Platforms: macOS, Linux, Windows (alpha), an iPhone app, and an `apps/android` folder (not inspected)
- A prebuilt engine downloads with `packages/ardiacore/scripts/fetch-engine.sh`. A local Chromium build is not needed to build the app
- Latest stable tag: `v0.2.46`

### Ardia already has a WebKit page engine

Added 2026-10-24, one day after the first analysis. It exists so DRM sites (Netflix and others) play through FairPlay.

- Setting `pageEngine: "chromium" | "webkit"` sets the default engine for all tabs. Per-site rules override it (`apps/browser/src/state/engines/engines.ts`)
- JS picks the native view by one prop: `<WebView engine="webkit">` mounts `ArdiaWebKit` instead of `ArdiaWebView` (`packages/ardiacore/src/WebView.tsx`)
- Native seam: protocols `PageTab` (one page) and `PageEngine` (per-engine services), each with a Chromium and a WebKit implementation
- WebKit side: 24 Swift files, ~3,300 lines (`packages/ardiacore/ios/WebKit*.swift`). One persistent `WKWebsiteDataStore` per profile, one non-persistent per private session
- WebKit pages are ad-blocked with uBlock Origin Lite rules compiled to `WKContentRuleList`
- Upstream's own list of what WebKit pages lack: extensions, password autofill, Chrome's site settings, page translation, notifications, passkeys (`docs/dia-feature-parity.md`, row "Protected video")
- `WebKitTab+PageTab.swift` shows the stubs: DevTools, tab discard and sleep, blocked popups, screen sharing, page cookies, Little Ardia and Peek modes

### Chromium still runs everything around the pages

- Process: `main.swift` calls `ArdiaHost.run`, which starts `ChromeMain`. `NSApp` is Chrome's application class
- Windows: each is an `ArdiaCoreWindow` (Chrome Views) made by `ArdiaChromeWindowHost`. `WindowManager.swift` falls back to a plain `BrowserWindow` when that returns nil
- Services: history, bookmarks, favicons, passwords, autofill, extensions, search engines, zoom and site settings are Chrome's, reached through 72 `ac_*` calls that exchange JSON. WebKit visits are written into Chrome's history
- Internal pages (`ardia://history`, `version`, `flags`, `gpu`) are Chrome's own pages under another name

### The engine API is typed and has stand-in precedents

- `packages/ardiacore/src/engine/api.ts` types 163 calls (`call("domain.verb", args)`) and 23 events
- `apps/browser/src/platform/` wraps those calls for the UI. `PLATFORM_FEATURES` turns features off per platform
- Windows answers calls it does not implement with a stand-in from a checked-in list (`docs/windows.md`, "Calls Windows still answers with a stand-in")
- `packages/demo` runs the whole UI in a web page on shims, with no engine at all
- Only 16 files in `packages/shell` use engine classes. `packages/import` and `packages/sync` use 4 engine calls in total, all for passwords

### iPhone app

`apps/ios` is SwiftUI on `WKWebView`. Its logic package `apps/ios/Packages/ArdiaKit` declares macOS 27 as a platform and holds history, tabs, content-blocking conversion and omnibox code. It is a reuse candidate for native stores.

### Contribution rules and licence

- Outside contributors may send bug fixes only. A new platform counts as a feature (`CONTRIBUTING.md`)
- Ardia's own source is Apache-2.0. The shipped app is GPL-3.0 only because the engine carries Helium's patches (`NOTICE`)

## Arc is ending

- Arc stops working on **2026-12-22**, on macOS and Windows ([arc.net](https://arc.net/)).
- Arc was in maintenance mode since May 2025. Atlassian bought The Browser Company in 2025. The company now builds Dia.

## Safari cannot be made into Arc

Safari Web Extensions can read and control tabs. They cannot:

- show a persistent sidebar (Safari has no `sidePanel` or `sidebar_action` API)
- hide or replace Safari's tab bar
- read or change Safari Tab Groups

The only UI surfaces are the toolbar popover and content scripts injected into each page. A sidebar injected into pages breaks on system pages and on sites with strict CSP.

A **companion Mac app** can float a panel next to Safari and drive tabs through AppleScript or Accessibility. Safari's own tab bar stays visible, so it always looks bolted on. [SupaSidebar](https://supasidebar.com/) is this approach, sold commercially.

## Own WebKit app is possible

Any Mac app can embed WebKit through `WKWebView`. That is the same engine as Safari, and it gets security fixes with macOS updates. Relevant APIs:

| Need | API | Min macOS |
|---|---|---|
| Web extensions | [`WKWebExtensionController`](https://developer.apple.com/documentation/webkit/wkwebextensioncontroller.md) | 15.4 |
| Separate profile per space | `WKWebsiteDataStore(forIdentifier:)` | 14 |
| Content blocking | `WKContentRuleList` | 10.13 |
| Downloads | `WKDownload` | 11.3 |
| Swipe back/forward | `allowsBackForwardNavigationGestures` | 10.11 |

**Unknown:** does iCloud Keychain or 1Password autofill work in a third-party WKWebView app? Nobody uses a browser daily without passwords. Phase 0 checks this.

## Existing WebKit projects

- [Ora](https://github.com/the-ora/browser): open source (GPL-3.0), Swift + WebKit. The README says it is "not ready for daily use yet". Its README does not mention vertical tabs or spaces.
- Orion (Kagi) and Refrax: WebKit with vertical tabs, closed source.

## Ardia: what it is

[Ardia](https://ardia.dev/) is a free macOS browser: "Arc's sidebar and Dia's polish on real Chromium". GPL-3.0.

| Part | Path | Size |
|---|---|---|
| UI (React Native for macOS + Expo, zustand store) | `apps/browser/src` | 332 TS files, ~51k lines |
| Native modules (Swift / ObjC++) | `packages/*/ios` | ~32k lines |
| Engine JS API | `packages/ardiacore/src` | 20 files, ~1.6k lines |
| Chromium patches + glue | `engine/` | 102 patch files |
| Importer (Arc spaces, Chrome, Safari, Firefox, Dia) | `packages/import` | 139 files |

### The seam that makes a port possible

- The UI talks to the engine **only through `@ardia/ardiacore`**. 72 of 332 UI files import it.
- The JS API covers: `WebView`, `autofill`, `bookmarks`, `chromeUI`, `contentBlocker`, `downloads`, `extensions`, `favicons`, `history`, `passwords`, `profiles`, `siteSettings`, `swipe`, `tabStrip`, `zoom`, and more.
- The native modules keep names from an older CEF engine (`ArdiaCEF`). So Ardia has swapped engines once already.
- The tab, space, pin and split model lives in JS: `apps/browser/src/store/` (`model.ts`, `types.ts`, `tabs.ts`, `splits.ts`, `profiles.ts`...).

### Chromium-specific parts (would be removed in a WebKit port)

- Chromium runs the process: `ChromeMain` starts first, then the React Native host starts inside Chrome's run loop.
- Every tab is a real Chrome tab. Passwords, autofill and extensions call Chrome services through C exports (`ArdiaCoreEngineBridge`).
- A full engine rebuild takes about 5 hours.

## Ardia: how it was built

| Metric | Value |
|---|---|
| First commit | 2026-09-25 (repo created 2026-06-19) |
| Commits | 1,522, of which 1,511 by one author |
| Days with commits | 28 |
| Busiest day | 186 commits |
| Commits with a `Co-Authored-By: Claude` trailer | 1,515 (Opus 5.5: 1,467, Sonnet 5.5: 48) |

The workflow from Ardia's `AGENTS.md` is worth copying:

1. **One orchestrator session.** It plans, hands work to Opus subagents, and checks what they return (build, run, capture).
2. **Codex as a second opinion** on risky logic (races, lifetimes, security), before and after the change. It reviews only and never edits.
3. **Parity checklist as source of truth.** `docs/dia-feature-parity.md` lists every feature. `docs/dia-spec.md` holds values measured from Dia (colors, sizes, animation timings in frames).
4. **Verify in hidden instances.** Test builds launch in the background with throwaway data dirs, and no focus steal. Checks use in-process snapshots.
5. **Commit straight to `main`.** No worktrees. Each agent stages only its own hunks.
