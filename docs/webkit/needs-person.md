# Foreground checks

Use a scratch profile in the rebuilt `Ardia WebKit.app`.

| Action | Expected result |
|---|---|
| Activate the scratch test window from its Dock icon | The window becomes key and accepts page input |
| Swipe back with two fingers after following a link | The previous page appears |
| Swipe forward with two fingers | The next page appears |
| Press Cmd+L on a page | The command bar takes focus |
| Press Esc in the command bar | Page input takes focus again |
| Enter element full screen from a page control | The element fills the display without browser chrome |
| Press Esc in element full screen | The page and browser chrome return |

Locked-session rows need another check run after unlocking this Mac. Automated foreground rows prove in-app AppKit routing; this checklist also checks physical input.

## Step 3 page features

| Action | Expected result |
|---|---|
| Choose Inspect, then press Option+Command+I on a fixture page | Web Inspector opens for that page; Inspect selects elements |
| Load the HTTP Basic fixture in a foreground scratch instance | Sign In accepts `fixture` / `correct`; Cancel displays the 401 page |
| Open a new tab in a dark space, then load a slow page | No white flash before the page draws |
| Open a fixture URL from another app with Little Ardia enabled | Small window opens; Open in Ardia preserves the page in the main window |

Automated checks log Inspector and HTTP auth requests in background mode. They do not prove visible panels or physical keyboard shortcuts.

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
