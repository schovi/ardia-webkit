import assert from "node:assert/strict";
import { test } from "node:test";
import { useBrowser } from "../browser/store.ts";
import {
  activeSteps,
  cancelOnboarding,
  chooseSource,
  confirmAnswer,
  customizeMore,
  finishOnboarding,
  dismissOnboarding,
  onboardingCompletedAt,
  previewLive,
  redoOnboarding,
  resolveDraft,
  draftPreset,
  skipStep,
  sourcePatch,
  startOnboarding,
  useOnboarding,
} from "./onboarding.ts";

const S = () => useBrowser.getState();
const O = () => useOnboarding.getState();
const settle = () => useOnboarding.setState({ windowId: null, leaving: false, redo: false, customizing: false });

test("onboarding has one appearance screen and finishes without import or upstream prompts", () => {
  const id = S().createWindow();
  startOnboarding(id);
  assert.equal(O().step, "look");
  assert.deepEqual(activeSteps(), ["look"]);
  confirmAnswer("look", { appearance: "dark" }, ["Dark appearance"]);
  assert.ok(onboardingCompletedAt());
  assert.equal(O().leaving, true);
  dismissOnboarding(O().session);
  assert.equal(O().windowId, null);
  assert.equal(S().settings.appearance, "dark");
  settle();
});

test("skipping the appearance screen reaches a usable browser", () => {
  const id = S().createWindow();
  startOnboarding(id);
  skipStep();
  assert.ok(onboardingCompletedAt());
  dismissOnboarding(O().session);
  assert.equal(O().windowId, null);
  assert.ok(S().windows[id]);
  settle();
});

test("redo starts from the current settings, keeps them unless a new browser is picked, and cancel undoes previews", () => {
  const id = S().createWindow();
  S().updateSettings({ appearance: "dark", searchEngine: "kagi", newTabOpens: "page", addressBar: "toolbar" });
  const completed = onboardingCompletedAt();
  assert.equal(redoOnboarding(id), id);
  assert.equal(O().step, "look");
  assert.equal(O().redo, true);
  const now = resolveDraft(["appearance", "searchEngine", "addressBar"], O().draft, draftPreset(O()), S().settings, []);
  assert.deepEqual(now, { appearance: "dark", searchEngine: "kagi", addressBar: "toolbar" });
  chooseSource(O().redoSource);
  assert.deepEqual(sourcePatch(), {});
  chooseSource(O().redoSource === "arc" ? "dia" : "arc");
  assert.ok(Object.keys(sourcePatch()).length > 0, "a different browser brings its preset");
  chooseSource(O().redoSource);
  previewLive({ appearance: "light" });
  assert.equal(S().settings.appearance, "light");
  cancelOnboarding();
  assert.equal(S().settings.appearance, "dark");
  assert.equal(S().settings.searchEngine, "kagi");
  assert.equal(onboardingCompletedAt(), completed, "redo never touches when onboarding was first finished");
  settle();
  assert.equal(redoOnboarding(id), id);
  finishOnboarding();
  assert.equal(onboardingCompletedAt(), completed);
  settle();
});
