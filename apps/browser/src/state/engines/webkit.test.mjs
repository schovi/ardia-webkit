import assert from "node:assert/strict";
import { test } from "node:test";
import { chromiumOnly, defaultEngine, tabEngine, typedNavigationEngine } from "./engines.ts";
import { DEFAULT_SETTINGS } from "../settings/settings.ts";

test("the WebKit fork ignores saved Chromium choices and internal URL restrictions", () => {
  const settings = { ...DEFAULT_SETTINGS, pageEngine: "chromium", websiteEngines: { "https://example.com": "chromium" } };
  const tabs = {
    saved: { id: "saved", url: "https://example.com", engine: "chromium" },
    adopted: { id: "adopted", url: "", page: { kind: "adopted", adopt: "ardiacore:9", nav: null } },
    internal: { id: "internal", url: "ardia://history", engine: "chromium" },
  };
  const state = { tabs, settings };
  assert.equal(DEFAULT_SETTINGS.pageEngine, "webkit");
  assert.equal(defaultEngine(state), "webkit");
  for (const tab of Object.values(tabs)) {
    assert.equal(tabEngine(state, tab.id), "webkit");
    assert.equal(typedNavigationEngine(state, tab, "https://example.com"), "webkit");
  }
  assert.equal(tabEngine(state, "missing"), "webkit");
  assert.equal(chromiumOnly("ardia://history"), false);
});
