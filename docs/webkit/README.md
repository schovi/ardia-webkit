# Ardia on WebKit

A fork of [Ardia](https://github.com/mantrakp04/ardia) that replaces its Chromium engine with WebKit (Safari's engine). An experiment.

Branch `webkit` holds the work. It is based on upstream stable tag `v0.2.46`.

Status: **a Release app (`Ardia WebKit`, 48 MB, no Chromium) passes a smoke pass of basic browsing** (Step 3 done, 2026-11-16). History, bookmarks, favicons, passwords and extensions are still stand-ins.

| File | What it holds |
|---|---|
| [engine-swap-plan.md](engine-swap-plan.md) | The current plan: how to remove Chromium and get a working WebKit version |
| [learnings.md](learnings.md) | Facts collected so far: Arc sunset, Safari limits, existing tools, how Ardia is built |
| [proposal.md](proposal.md) | The first proposal. Its decision and the later move to native UI still hold |

## Build

```sh
mise exec node@24 pnpm@11.1.3 -- pnpm install
mise exec node@24 pnpm@11.1.3 -- xcodebuild -workspace apps/browser/macos/Ardia.xcworkspace -scheme Ardia-macOS \
  -derivedDataPath apps/browser/build-webkit -destination platform=macOS,arch=arm64 -configuration Release \
  -xcconfig apps/browser/macos/AdHoc.xcconfig build
```

The app lands in `apps/browser/build-webkit/Build/Products/Release/Ardia WebKit.app`. It is ad hoc signed with no entitlements. It uses its own bundle id (`com.ardia.webkit`), config folder (`~/.config/ardia-webkit`) and keychain item names, so it can sit next to a stock Ardia.

## Next action

Step 5 of the plan: favicons, history and search suggestions on native stores.
