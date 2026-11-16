import assert from "node:assert/strict";
import { test } from "node:test";
import { launch } from "../../test-native/index.ts";
import { reloadLaunchConfigForTests } from "../../platform/launchConfig.ts";
import { feedbackEndpoint, openReport, sendCurrentReport } from "./actions.ts";
import { currentReport } from "./store.ts";

test("reports cannot open or send, including with a launch endpoint override", async () => {
  launch.feedbackURL = "https://override.invalid/feedback";
  reloadLaunchConfigForTests();
  assert.equal(feedbackEndpoint(), "");
  let requests = 0;
  const previous = globalThis.fetch;
  globalThis.fetch = async () => { requests++; throw new Error("must not send"); };
  try {
    openReport("window");
    assert.equal(currentReport().windowId, null);
    await sendCurrentReport();
    assert.equal(requests, 0);
  } finally { globalThis.fetch = previous; }
});
