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
