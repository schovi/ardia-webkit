import assert from "node:assert/strict";
import { test } from "node:test";

globalThis.__DEV__ = false;
const { useBrowser } = await import("../browser/store.ts");
const { launchTab } = await import("./launchTab.ts");
const { loadSession, flushPersistence, startPersistence } = await import("../session/persist.ts");
const stub = await import("../../test-native/index.ts");

const S = () => useBrowser.getState();
startPersistence();
const tab = (id, windowId, url, profileId = "default") => ({
  id, windowId, profileId, url, title: "", favicon: null, pin: null, muted: false, zoom: 1, customTitle: null, customIcon: null,
  pinnedUrl: null, page: { kind: "idle" }, openerId: null, createdAt: 0, lastActiveAt: 0,
});
const win = (id, tabIds, active, extra = {}) => ({
  id, profileId: "default", kind: "main", tabIds, activeTabIds: { default: active }, sidebarOpen: true, frame: null, createdAt: 0, ...extra,
});
const PROFILES = {
  default: { id: "default", name: "Personal", color: "plum", icon: null, createdAt: 0 },
  work: { id: "work", name: "Work", color: "blue", icon: null, createdAt: 0 },
};
const hydrate = (windows, tabs, extra = {}) =>
  S().hydrate({ profiles: PROFILES, windows: Object.fromEntries(windows.map((w) => [w.id, w])), tabs: Object.fromEntries(tabs.map((t) => [t.id, t])), ...extra });

test("WebKit loads the focused page without a Chromium launch hint", () => {
  hydrate([win("w1", ["a", "b"], "b"), win("w2", ["c"], "c")], [tab("a", "w1", "https://a.com/"), tab("b", "w1", "https://b.com/x"), tab("c", "w2", "http://c.com/")], { focusedWindowId: "w1" });
  assert.deepEqual(launchTab(S(), (S().ui.focusOrder[0] ?? null)), null);
  assert.deepEqual(launchTab(S(), "w2"), null);
  assert.equal(S().tabs.b.page.nav?.url, "https://b.com/x");
});

test("another profile also needs no Chromium launch hint", () => {
  hydrate([win("w1", ["a"], null, { profileId: "work", activeTabIds: { work: "a" } })], [tab("a", "w1", "https://a.com/", "work")], { focusedWindowId: "w1" });
  assert.deepEqual(launchTab(S(), "w1"), null);
});

test("nothing for a page the engine doesn't load at launch", () => {
  for (const url of ["", "about:blank", "ardia://history", "chrome://settings", "file:///tmp/x.html", "javascript:alert(1)"]) {
    hydrate([win("w1", ["a"], "a")], [tab("a", "w1", url)], { focusedWindowId: "w1" });
    assert.equal(launchTab(S(), "w1"), null, url);
  }
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1" });
  assert.equal(launchTab(S(), null), null, "no focused window");
  assert.equal(launchTab(S(), "gone"), null);
  assert.equal(launchTab({ ...S(), settings: { ...S().settings, restoreSession: false } }, "w1"), null, "a session the user doesn't restore");
  assert.equal(launchTab({ ...S(), windows: { w1: { ...S().windows.w1, kind: "private" } } }, "w1"), null, "private");
  assert.equal(launchTab({ ...S(), windows: { w1: { ...S().windows.w1, kind: "small" } } }, "w1"), null, "Little Ardia");
});

test("session restore keeps the selected tab without a Chromium hint", () => {
  hydrate([win("w1", ["a", "b"], "a"), win("w2", ["c"], "c")], [tab("a", "w1", "https://a.com/"), tab("b", "w1", "https://b.com/"), tab("c", "w2", "https://c.com/")], { focusedWindowId: "w2" });
  S().activate("b");
  S().setFocusedWindow("w1");
  flushPersistence();
  const saved = JSON.parse(stub.docs.get("session.json"));
  assert.equal(saved.launchTab, null);
  S().hydrate(loadSession());
  assert.deepEqual(launchTab(S(), (S().ui.focusOrder[0] ?? null)), saved.launchTab);
  assert.equal(S().windows.w1.activeTabIds.default, "b");
  assert.equal(S().tabs.b.url, "https://b.com/");
});

test("a reopened tab not shown yet keeps its back/forward list across a relaunch; nothing else pending does", () => {
  const waking = (id, wake, profileId) => ({ ...tab(id, "w1", `https://${id}.com/`, profileId), page: { kind: "idle", wake } });
  hydrate(
    [win("w1", ["a", "b", "c", "p"], "a")],
    [tab("a", "w1", "https://a.com/"), waking("b", "restore:old-b"), waking("c", "tab:42"), waking("p", "restore:old-p", "incognito:w9@default")],
    { focusedWindowId: "w1" },
  );
  flushPersistence();
  const saved = Object.fromEntries(JSON.parse(stub.docs.get("session.json")).tabs.map((t) => [t.id, t.page.wake]));
  assert.deepEqual(saved, { a: undefined, b: "restore:old-b", c: undefined, p: undefined }, "only a regular tab's restore");
  S().hydrate(loadSession());
  assert.equal(S().tabs.b.page.wake, "restore:old-b");
  S().activate("b");
  assert.equal(S().tabs.b.page.adopt, "restore:old-b", "shown, it wakes with its list");
  S().setFocusedWindow("w1");
  assert.deepEqual(launchTab(S(), "w1"), null, "woken, the next launch loads it by its address");
  S().updateTab("b", { page: { kind: "idle", wake: "restore:old-b" } });
  assert.equal(launchTab(S(), "w1"), null, "not woken yet: it keeps its list");
});

test("no hint when the next launch won't restore the session", () => {
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1" });
  S().updateSettings({ restoreSession: false });
  flushPersistence();
  assert.equal(JSON.parse(stub.docs.get("session.json")).launchTab, null);
});

const savedHint = () => (flushPersistence(), JSON.parse(stub.docs.get("session.json")).launchTab);

test("session.json names the profile the next launch opens links from other apps in", () => {
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1", lastProfileId: "work" });
  flushPersistence();
  assert.equal(JSON.parse(stub.docs.get("session.json")).linkProfile, "work");
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1" });
  flushPersistence();
  assert.equal(JSON.parse(stub.docs.get("session.json")).linkProfile, "");
});

test("an adopted WebKit page restores by URL without a Chromium launch hint", () => {
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1" });
  const id = S().newTab("w1", { url: "https://made.example/page", adoptId: "webkit:7" });
  assert.equal(S().tabs[id].page.adopt, "webkit:7");
  assert.equal(savedHint(), null);
  S().hydrate(loadSession());
  assert.equal(S().tabs[id].page.adopt, undefined);
  assert.equal(S().tabs[id].page.nav?.url, "https://made.example/page");
});

test("navigation, selection, closure and window changes persist without a native launch hint", () => {
  hydrate([win("w1", ["a", "b"], "a"), win("w2", ["c"], "c")], [tab("a", "w1", "https://a.com/"), tab("b", "w1", "https://b.com/"), tab("c", "w2", "https://c.com/")], { focusedWindowId: "w1" });
  S().updateTab("a", { url: "https://a.com/next", title: "Next" }, { isLoading: false, canGoBack: true, canGoForward: false });
  flushPersistence();
  assert.equal(JSON.parse(stub.docs.get("session.json")).tabs.find((t) => t.id === "a").url, "https://a.com/next");
  S().activate("b");
  flushPersistence();
  S().hydrate(loadSession());
  assert.equal(S().windows.w1.activeTabIds.default, "b");
  S().closeTab("b");
  S().setFocusedWindow("w2");
  assert.equal(savedHint(), null);
  S().hydrate(loadSession());
  assert.equal(S().tabs.b, undefined);
  assert.equal(S().ui.focusOrder[0], "w2");
  assert.equal(S().windows.w1.activeTabIds.default, "a");
});

test("after a crash the saved WebKit session keeps its last persisted URL", () => {
  hydrate([win("w1", ["a"], "a")], [tab("a", "w1", "https://a.com/")], { focusedWindowId: "w1" });
  flushPersistence();
  S().updateTab("a", { url: "https://a.com/lost", title: "" }, { isLoading: false, canGoBack: true, canGoForward: false });
  const onDisk = JSON.parse(stub.docs.get("session.json"));
  S().hydrate(loadSession());
  assert.equal(onDisk.launchTab, null);
  assert.equal(onDisk.tabs.find((t) => t.id === "a").url, "https://a.com/");
  assert.equal(S().tabs.a.url, "https://a.com/");
});
