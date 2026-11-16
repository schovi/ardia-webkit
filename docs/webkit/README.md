# Ardia on WebKit

A fork of [Ardia](https://github.com/mantrakp04/ardia) that replaces its Chromium engine with WebKit (Safari's engine). An experiment.

Branch `webkit` holds the work. It is based on upstream stable tag `v0.2.46`.

Status: **the app boots with no Chromium and loads pages in WebKit tabs** (Step 2 done, 2026-11-16). Browser data services are still stand-ins.

| File | What it holds |
|---|---|
| [engine-swap-plan.md](engine-swap-plan.md) | The current plan: how to remove Chromium and get a working WebKit version |
| [learnings.md](learnings.md) | Facts collected so far: Arc sunset, Safari limits, existing tools, how Ardia is built |
| [proposal.md](proposal.md) | The first proposal. Its decision and the later move to native UI still hold |

## Next action

Step 3 of the plan: a Release build that runs without Metro, then a smoke pass of daily basics.
