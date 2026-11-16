# Ardia on WebKit

A fork of [Ardia](https://github.com/mantrakp04/ardia) that replaces its Chromium engine with WebKit (Safari's engine). An experiment.

Branch `webkit` holds the work. It is based on upstream stable tag `v0.2.46`.

Status: **plan accepted, spike not started.**

| File | What it holds |
|---|---|
| [engine-swap-plan.md](engine-swap-plan.md) | The current plan: how to remove Chromium and get a working WebKit version |
| [learnings.md](learnings.md) | Facts collected so far: Arc sunset, Safari limits, existing tools, how Ardia is built |
| [proposal.md](proposal.md) | The first proposal. Its decision and the later move to native UI still hold |

## Next action

Step 2 of the plan: boot the app with no Chromium linked.
