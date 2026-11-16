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
