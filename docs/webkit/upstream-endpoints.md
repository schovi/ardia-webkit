# Step 1: upstream endpoints

The fork disables upstream services at their shared boundaries. It keeps the existing UI components and upload code for later upstream rebases.

## Disabled paths

Paths below are relative to the repository root.

| Endpoint | Boundary that disables it |
|---|---|
| `https://ardia.dev/otel/v1/logs` (daily counts, events, logs, crash reports, report watches) | `apps/browser/src/state/telemetry/config.ts:1` empties `LOGS_URL`; `transport.ts:12` refuses every post, including development overrides. |
| `https://ardia.dev/api/feedback` | `apps/browser/src/state/report/actions.ts:32` empties `FEEDBACK_URL`; `feedbackEndpoint` ignores launch overrides. `openReport` and `sendCurrentReport` return before opening or sending. |
| Feedback `/api/feedback/<id>/complete`, `/api/feedback/<id>/files/<name>`, and server-supplied attachment upload URLs | The same `sendCurrentReport` guard prevents create, resumed uploads, file uploads, and completion. These paths come from `state/report/upload.ts`. |
| `https://ardia.dev/switches.json` | `apps/browser/src/platform/killSwitches.ts:87` empties `SWITCHES_URL`. JS ignores cached remote values. `packages/ardiacore/ios/ArdiaLaunchConfig.mm:275` ignores native cached values. Local launch overrides still work. |
| `https://ardia.dev/release-notes` | `apps/browser/macos/Ardia-macOS/Info.plist:10` empties `ACReleaseNotesURL`. Both manual and after-update opening use this value. |
| `https://github.com/mantrakp04/ardia/releases/latest/download/appcast.xml`, any configured appcast, and its update or release-note URLs | `packages/shell/ios/AppUpdater.swift:173` forces `isOff` true. This also disables instance and UserDefaults feed overrides. The checked-in `SUFeedURL` is already empty. |
| `https://github.com/mantrakp04/ardia/issues/new?body=%s` | `apps/browser/macos/Ardia-macOS/Info.plist:8` empties the legacy `ACFeedbackURL`. |
| `https://services.helium.imput.net/bangs.json`, including the development override | `packages/shell/ios/BangListFetch.swift:30` returns before creating a session. The bundled bang snapshot remains available. |

## Other URLs found

`AppUpdater.swift` and the Advanced pane keep GitHub source, license, and credits links. A user opens these as web content. They are not automatic app requests.

`SharePicker.swift` uses `https://ardia.dev` as a sample item for local sharing-service discovery. `SystemModule.swift` uses `https://example.com` to look up the default browser. Neither code path fetches the sample URL.

The live-folder integrations use GitHub, Bitbucket, Notion, a user-supplied Confluence host, and Google OAuth and Drive endpoints. They need a configured account. Step 1 does not change these third-party integrations.

Search suggestions use the selected provider's endpoint from `packages/core/src/engines.ts`. Native favicons fetch page-selected icon URLs through `webkit/Network.mm`. JS icon sampling fetches those icon URIs. Notification attachments use an explicitly supplied icon URL in `NotificationHub.swift`.

The inventory covered browser JS and TS, shell Swift, ArdiaCore Swift and Objective-C, compiled WebKit replacements, and the app plist. Chromium implementations excluded by `ArdiaCore.podspec` do not execute in this app. Plist DTDs, schema identifiers, fixtures, placeholders, bundled bang destinations, and page-script URLs are not app-owned upstream services.

## Verification

`scripts/webkit/check` includes `no-upstream`. It observes app-process HTTP and HTTPS requests from before startup through quit, for at least 90 seconds. A fresh profile completes the appearance screen through the harness and loads a fixture page. Telemetry sharing starts enabled.

The row requires JS and native requests to appear in the observation and reach the fixture. It rejects any other origin. It retains the request list and three in-process snapshots under `apps/browser/build-webkit/step-1-evidence/`.

The observer covers URL Loading System requests. It does not capture raw sockets, OS services, or WebKit's separate network process. The source inventory found no additional app-owned upstream transport outside that system.

## Settings response repairs

The Privacy crash came from `ArdiaContentBlocker.state` returning `{}`. Its hand-written replacement reads the existing WebKit state and bundled list metadata. It supplies real ready/enabled flags, selected lists, allowed hosts, version, filter counts, error, and the sum of live tabs' blocked counts (`stats.blocked`). Unavailable lookup and parse timings default to zero.

The Settings tour also found malformed extension and bookmark responses during startup and pane prefetch. These read-only placeholders keep the UI renderable until their planned implementation steps:

| Pane or path | Call | Placeholder | Future step |
|---|---|---|---|
| General prefetch and Extensions | `ArdiaServices.listExtensions` / `extensions.list` | `{extensions: []}` | 8 |
| Startup and Extensions | `ac_extensions_load_health` | `{dropped: 0, enabled: 0, disabled: {}}` | 8 |
| Startup and Extensions | `ac_extensions_watch_actions` | `{}` acknowledgement; no watch | 8 |
| Startup before Settings | `ac_bookmarks_watch` | `{}` acknowledgement; no watch | 5 |
| Startup before Settings | `ac_bookmarks_tree` | Empty `bar` and `other` folder roots, each with `id`, `k: "f"`, `t`, `a: 0`, `c: []` | 5 |

`setEnabled`, `setList:enabled`, and `setAllowed:onHost` now control WebKit in Step 4. The extension and bookmark placeholders above remain unchanged. The tour checks all 14 available top-level panes, including advanced panes; it does not test sheets or setting actions.
