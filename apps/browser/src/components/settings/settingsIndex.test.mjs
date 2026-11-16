import assert from "node:assert/strict";
import { test } from "node:test";
import { PANES, SETTINGS, unshownSettings } from "./settingsIndex.ts";
import { DEFAULT_SETTINGS } from "../../state/settings/settings.ts";
import { goToSettingsPane, useSettingsNav } from "../../state/settings/settingsWindows.ts";

const REMOVED_ROWS = ["privacy.shareDiagnostics", "privacy.whatsSent", "privacy.anonymousId", "general.updateChecks", "general.autoUpdate", "general.updateChannel", "general.checkNow", "advanced.chromium", "advanced.widevine"];

test("upstream rows stay hidden with advanced settings on and off", () => {
  for (const showAdvancedSettings of [false, true]) {
    const hidden = new Set(unshownSettings({ ...DEFAULT_SETTINGS, showAdvancedSettings }, { top: false, glass: true }).split("\n"));
    for (const id of REMOVED_ROWS) assert.ok(hidden.has(id), id);
    assert.ok(!hidden.has("general.downloadsFolder"));
  }
});

test("Engines has no sidebar or search entries and cannot be opened", () => {
  assert.ok(!PANES.some(pane => pane.id === "engines"));
  assert.ok(!SETTINGS.some(row => row.pane === "engines"));
  goToSettingsPane("engines");
  assert.equal(useSettingsNav.getState().pane, "general");
});
