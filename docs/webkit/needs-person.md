# Foreground checks

Use a scratch profile in the rebuilt `Ardia WebKit.app`.

| Action | Expected result |
|---|---|
| Swipe back with two fingers after following a link | The previous page appears |
| Swipe forward with two fingers | The next page appears |

Automated foreground rows prove page typing, Cmd+L, Esc, history shortcuts, window and element full screen, and Inspector windows. They post input inside Ardia. Physical input delivery through WindowServer remains unchecked. Screen-lock skips require another run after unlocking.

## Step 3 page features

| Action | Expected result |
|---|---|
| Load the HTTP Basic fixture in a foreground scratch instance | Sign In accepts `fixture` / `correct`; Cancel displays the 401 page |
| Open a new tab in a dark space, then load a slow page | No white flash before the page draws |
| Open a fixture URL from another app with Little Ardia enabled | Small window opens; Open in Ardia preserves the page in the main window |

The Inspector row proves selection mode, a visible detached frontend, and reopening through queued Option+Command+I. HTTP auth checks still log prompts in background mode; visible sheet input remains manual.

## Step 4 settings

| Action | Expected result |
|---|---|
| Choose a scratch download folder, enable Ask Where to Save, and download a fixture file | The save panel starts in that folder. Cancel saves nothing. Relaunch retains both preferences. |
| Open About in a foreground scratch instance | The panel shows the app version and system WebKit version, without Chromium wording. |
| Allow or block location in Settings, then request location from a trusted test page | The stored setting remains visible. Automated checks prove storage only and never request macOS location consent. |

Camera and microphone checks invoke the real WKUIDelegate decision callback using a fixture frame. They never start capture or request macOS consent. Hardware capture remains unchecked.

## Step 5 bookmarks

| Action | Expected result |
|---|---|
| Drag a bookmark within the bar, into a folder, and within that folder | The drop changes order or parent. Relaunch retains the result. Automated checks use the same `moveBookmark` action. |
| Add a page with Cmd+D, edit its name and folder, then press Done | The dialog accepts physical input and the bar shows the saved bookmark. Automated checks drive the command and rendered Done button. |
| Export bookmarks in a foreground scratch instance | The save panel writes Netscape HTML at the chosen scratch path. Cancel writes nothing. Background checks bypass the panel. |


## Step 7 passwords

| Action | Expected result |
|---|---|
| Type a fixture login by hand, submit, and accept Save or Update | The unchanged prompt appears after navigation. Relaunch retains the accepted login. |
| Focus a field with two saved accounts, including in a same-origin iframe and with page zoom changed | The native menu appears under the field. Selecting an account fills only that login. |
| Unlock, reveal, edit, and export passwords in a normal foreground instance | Touch ID or the login password gates disclosure. Cancel discloses nothing. The save panel uses the chosen scratch path. |
| Access the app-owned password key after installing a new ad hoc build | macOS may ask once to allow access for that build. Stable signing remains the owner's prerequisite for removing this prompt. |

Automated checks use only the file keychain and the `reauth` test switch. They never evaluate LocalAuthentication or request real Keychain access. macOS Passwords autofill inside a third-party WKWebView remains unchecked.

## Step 8 extensions

| Action | Expected result |
|---|---|
| Install `scripts/webkit/fixtures/extension-content` from Settings in a scratch profile | One permissions prompt appears. Cancel installs nothing. Accept lists the managed copy. |
| Click Add to Ardia on a real Chrome Web Store detail page in a scratch profile | The existing name, permission, and host prompt appears. Decline installs nothing. Accept changes the button to Added, including after reload. |
| Pin the fixture and physically click its toolbar action | The icon and badge `8` appear. The popup opens below the button and accepts focus. |
| Click outside the popup, press Esc, and switch tabs | The popup closes. A later click opens a fresh popup. |
| Disable, enable, reload, and remove the fixture through Settings | The displayed state matches injection. Relaunch retains the enabled state and permissions. |

The foreground action row now gets a key window. Native mouse events close and reopen the popup. DOM, dimensions, opacity, and a snapshot prove visible content. Physical input and focus still need a person. Bitwarden 2026.10.2 fails in its background worker; its initial popup DOM read was empty.
