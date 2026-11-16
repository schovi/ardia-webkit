# Proposal: Ardia on WebKit, then native UI

> **2026-11-16:** Phase 0 and Phase 1 below are replaced by the [engine swap plan](engine-swap-plan.md). Upstream added its own WebKit page engine, so the swap is smaller and cuts at a different place. The Decision, Phase 2 and Phase 3 still hold.

## Decision

**Fork Ardia and replace its Chromium engine with WebKit, keeping its React Native UI. Move to native UI later, and only when a trigger below fires.**

Why this order:

- Ardia's UI reaches the engine through one package (`@ardia/ardiacore`, ~1.6k lines of JS API). Swapping that package is far smaller than writing a browser UI from zero.
- The two real unknowns (passwords, extensions) live in the engine layer. They block every path equally, so they get checked first and cheaply.
- Keeping the React Native UI keeps upstream Ardia features flowing in. A native rewrite gives that up, so it must buy something measurable.

Options considered:

| Option | Gain | Cost |
|---|---|---|
| **A. Fork Ardia, swap engine** (chosen) | Usable browser fastest. Arc importer, sidebar, spaces, splits all reused | Stuck with React Native macOS for now |
| B. Native app from scratch (like Ora) | Clean native code from day one | Rebuild ~51k lines of UI before it is usable |
| C. Sidebar app next to Safari | No browser to maintain | Safari's tab bar stays visible. Never feels like Arc |

## Phase 0: spike, answer the two unknowns

A throwaway Swift app with one `WKWebView`, outside the Ardia fork.

1. **Passwords.** Log in to a site. Check if iCloud Keychain autofill appears. Then install 1Password and check its autofill.
2. **Extensions.** Load unpacked uBlock Origin and 1Password through `WKWebExtensionController`. Check that the toolbar action and a content script work.

| Result | Meaning |
|---|---|
| Both work | Go to Phase 1 |
| Extensions work, passwords don't | Go, with 1Password/Bitwarden extension as the password story |
| Neither works | Stop. A WebKit browser without passwords and extensions is not a daily driver |

Effort: complexity low, blast radius none (throwaway), risk low.

## Phase 1: engine swap

Goal: Ardia's UI running on WebKit, browsing works, Arc import works.

1. Fork Ardia. Ask the author first (Discord in the repo description) whether a WebKit engine could live upstream as a second backend. That beats a fork that falls behind.
2. Create `packages/webkitcore` as an Expo module. It exports the same JS API as `packages/ardiacore/src`.
3. Point the app at it. Start with a stub where every call is a no-op, and make the app boot.
4. Implement module by module:

| ArdiaCore module | WebKit implementation | Difficulty |
|---|---|---|
| `WebView`, `history`, `favicons`, `zoom`, `swipe` | `WKWebView`, `WKNavigationDelegate`, `pageZoom`, `allowsBackForwardNavigationGestures` | Easy |
| `profiles` | `WKWebsiteDataStore(forIdentifier:)`, one store per profile | Easy |
| `contentBlocker` | `WKContentRuleList`. Convert uBlock lists or reuse an existing converter | Easy |
| downloads, `siteSettings`, permissions | `WKDownload`, `WKUIDelegate`. Build our own permission prompts | Medium |
| `extensions` | `WKWebExtensionController`. Build install from Chrome Web Store (download CRX, unpack, load) | Hard |
| `passwords`, `autofill` | Depends on Phase 0 result | Unknown |
| `chromeUI`, `tabStrip`, `cliControl` | Delete. They exist to hide or drive Chromium's own UI | Deletion |

5. Remove `engine/` and `packages/ardiacore`. The app becomes a normal `NSApplication` (no `ChromeMain`).
6. Set minimum macOS to 15.4 (needed for `WKWebExtensionController`).

Done when: daily browsing in the fork for one week without falling back to another browser.

Effort: complexity medium, blast radius one package plus app bootstrap, risk medium. Unknowns: how many UI files assume Chromium behavior beyond the import seam (Step 3 shows this).

## Phase 2: daily-driver gaps

Only what Phase 1 use shows is missing. Expected candidates:

- Permission prompt UI (camera, mic, location, notifications)
- Extension install flow and the toolbar area for extension actions
- Tab memory: WebKit has no tab discarding, so close and recreate the `WKWebView` for old tabs and keep the URL and title
- DRM video (Netflix, Spotify web): check that FairPlay works in `WKWebView`. Widevine is not available on WebKit

## Phase 3: evolve to native UI

### Why we might want it

- **Two runtimes.** The JS runtime and the React Native bridge sit between every tab event (title, favicon, progress) and the sidebar. With hundreds of tabs, that costs memory and input latency.
- **React Native macOS is a weak base.** Ardia runs the Legacy architecture and carries patches to `react-native-macos` internals for focus, text editing, mouse events and layout. Each one is a place where AppKit already does the right thing.
- **AppKit gives things for free** that Ardia rebuilt or patched: drag and drop, accessibility, keyboard focus, text field editing, menus.

### Why not yet

- It ends upstream sync with Ardia. After the store moves to Swift, upstream UI changes no longer merge.
- React Native reloads JS without a rebuild. That keeps the agent loop fast while features still change weekly.
- ~51k lines of UI is a lot to rewrite with no user-visible gain.

### Triggers (start Phase 3 when one of these is true)

1. Upstream sync stops paying: we diverged, or upstream went in a direction we don't follow.
2. A measured UI problem traced to React Native: sidebar input latency, memory per window, startup time.
3. A `react-native-macos` patch blocks a dependency update.

### How: replace piece by piece, never a big-bang rewrite

1. **Move the model to Swift first.** Port `apps/browser/src/store/` (`model.ts`, `types.ts`, `tabs.ts`, `splits.ts`, `profiles.ts`, persistence) to a Swift package, `BrowserCore`. The JS store becomes a read-only mirror that subscribes to native changes. This is the hard step, and the one that ends upstream sync.
2. **Replace surfaces one at a time** with native views. React Native hosts them through Expo native views, so both UIs run side by side. Order by value:
   1. Sidebar (most interaction, most React Native patches)
   2. Omnibox and command bar
   3. Split view and window chrome
   4. Settings, onboarding (least value, last)
3. **Remove React Native** when `App.tsx` only hosts native views. Delete Metro, Expo and the JS store. The app shell becomes plain AppKit.

UI tech per surface:

| Surface | Tech | Why |
|---|---|---|
| Sidebar | AppKit (`NSOutlineView` or custom `NSView`) | Fine control of drag, hover and animation timing that an Arc-style sidebar needs |
| Omnibox, command bar | AppKit text field + SwiftUI list | Native text editing and focus |
| Settings, onboarding, popovers | SwiftUI | Forms and static layout, where SwiftUI is fastest to write |

Keep the agent loop fast without Metro: snapshot tests of each view, and a debug build that reloads the model from a fixture.

Effort: complexity high, blast radius whole app, risk medium (done piece by piece, each step ships). Unknowns: performance numbers that would justify it (measure in Phase 2).

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| No password autofill in WKWebView | Not a daily driver | Phase 0 checks it before any other work |
| Chrome extensions fail on WKWebExtension | Lose uBlock, 1Password | Phase 0. Built-in content blocker covers ads |
| Ardia upstream moves fast (~50 commits/day) | Merge pain | Ask for upstream WebKit backend. Rebase often in Phase 1 and 2 |
| GPL-3.0 | Fork must stay GPL | Fine for a free tool |
| macOS 15.4+ only | Older Macs excluded | Accept |

## Workflow

Copy Ardia's agent setup (see [learnings](learnings.md#ardia-how-it-was-built)): one orchestrator session, Opus subagents per module, Codex review for engine and lifetime code, a parity checklist (`docs/webkit-parity.md`) with one row per `ardiacore` export.
