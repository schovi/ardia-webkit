import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

globalThis.__DEV__ = false;
const { docs, launch } = await import("../test-native/index.ts");
const ks = await import("./killSwitches.ts");
const { reloadLaunchConfigForTests } = await import("./launchConfig.ts");

const names = Object.keys(ks.SWITCHES);
const reset = () => {
  docs.clear();
  launch.switches = {};
  reloadLaunchConfigForTests();
  ks.reloadSwitches();
  ks.resetRefreshForTests();
};
const file = (switches) => ({ version: 1, switches });

test("at most 8 live switches, each on by default with an owner and a removal date still ahead", () => {
  assert.ok(names.length <= ks.MAX_SWITCHES, `${names.length} switches: delete one before adding another (cap ${ks.MAX_SWITCHES})`);
  const today = new Date().toISOString().slice(0, 10);
  for (const name of names) {
    const def = ks.SWITCHES[name];
    assert.match(def.removeBy, /^\d{4}-\d{2}-\d{2}$/, name);
    assert.ok(def.removeBy >= today, `${name} is past its removal date (${def.removeBy}): delete it and its old path, or move the date with a reason`);
    assert.ok(def.owner.trim() && def.about.trim(), name);
    assert.equal(typeof def.live, "boolean", name);
  }
  reset();
  for (const name of names) assert.equal(ks.switchOn(name), true, `${name} defaults on`);
});

test("the site's switches.json is a version 1 file naming only switches the app knows, as booleans", () => {
  const site = JSON.parse(readFileSync(new URL("../../../site/public/switches.json", import.meta.url), "utf8"));
  assert.equal(site.version, 1);
  for (const [name, value] of Object.entries(site.switches)) {
    assert.ok(names.includes(name), `switches.json names ${name}, which the app doesn't have: remove it`);
    assert.equal(typeof value, "boolean", name);
  }
  assert.ok(JSON.stringify(site).length < 4096);
});

test("cached remote values never change built-in defaults", () => {
  reset();
  docs.set("switches-cache.json", JSON.stringify(file(Object.fromEntries(names.map(name => [name, false])))));
  for (const name of names) assert.equal(ks.switchOn(name), true);
  launch.switches = { sidebarSlide: false };
  reloadLaunchConfigForTests();
  assert.equal(ks.switchOn("sidebarSlide"), false);
  reset();
});

test("experiments are off unless ARDIA_SWITCHES turns them on, and don't count against the live cap", () => {
  reset();
  const today = new Date().toISOString().slice(0, 10);
  for (const [name, def] of Object.entries(ks.EXPERIMENTS)) {
    assert.ok(!names.includes(name), `${name} is both a kill switch and an experiment`);
    assert.ok(def.owner.trim() && def.about.trim(), name);
    assert.ok(def.removeBy >= today, `${name} is past its removal date (${def.removeBy})`);
    assert.equal(ks.experimentOn(name), false, `${name} defaults off`);
  }
  launch.switches = { webkitSignIn: true };
  reloadLaunchConfigForTests();
  assert.equal(ks.experimentOn("webkitSignIn"), true);
  reset();
});

test("refresh never fetches or overwrites the cache, including repeated launches", async () => {
  reset();
  docs.set("switches-cache.json", JSON.stringify(file({ sidebarSlide: false })));
  const before = docs.get("switches-cache.json");
  let calls = 0;
  const fetchFn = async () => { calls++; throw new Error("must not fetch"); };
  for (let i = 0; i < 3; i++) {
    ks.resetRefreshForTests();
    ks.reloadSwitches();
    assert.equal(await ks.refreshSwitches(fetchFn), "disabled");
    assert.equal(ks.switchOn("sidebarSlide"), true);
    assert.equal(docs.get("switches-cache.json"), before);
  }
  assert.equal(calls, 0);
});

test("every switch and experiment native and engine code read by name is in the registry", async () => {
  const { execFileSync } = await import("node:child_process");
  const root = new URL("../../../../", import.meta.url).pathname;
  const pattern = String.raw`(switchOn|experimentOn|SwitchOn|ExperimentOn)\("[A-Za-z]+"\)`;
  const hits = execFileSync("git", ["grep", "-hoE", pattern, "--", ":(glob)packages/*/ios/**", "engine", "apps/browser/macos"], { cwd: root, encoding: "utf8" });
  const read = hits.trim().split("\n").map((hit) => hit.match(/^(\w+)\("(\w+)"\)$/));
  assert.ok(read.length >= 4, "found the native reads");
  for (const [, kind, name] of read) {
    const registry = /^[sS]witchOn$/.test(kind) ? ks.SWITCHES : ks.EXPERIMENTS;
    assert.ok(Object.hasOwn(registry, name), `${kind}("${name}") reads a name the registry in platform/killSwitches.ts doesn't have`);
  }
});
