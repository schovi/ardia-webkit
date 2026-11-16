import assert from "node:assert/strict";
import { test } from "node:test";

globalThis.__DEV__ = false;
const stub = await import("../../test-native/index.ts");
Object.assign(stub.appInfo, { appVersion: "0.3.0", osVersion: "26.1", arch: "arm64", isolatedInstance: false });
const daily = await import("./daily.ts");
const { appInfo } = await import("./transport.ts");

const at = (iso) => Date.parse(`${iso}T12:00:00Z`);
const store = (lastDay) => (lastDay ? stub.docs.set(daily.DAILY_DOC, JSON.stringify({ version: 1, lastDay })) : stub.docs.delete(daily.DAILY_DOC));
const posts = [];
let status = 200;
globalThis.fetch = async (url, init) => {
  posts.push({ url, body: JSON.parse(init.body) });
  if (status === 0) throw new Error("offline");
  return { status };
};
const reset = (lastDay, installedBefore = false) => {
  store(lastDay);
  posts.length = 0;
  status = 200;
  daily.resetDailyForTests(installedBefore);
};

test("ISO weeks start on Monday, across years", () => {
  assert.equal(daily.isoWeekMonday("2026-10-25"), "2026-10-19");
  assert.equal(daily.isoWeekMonday("2026-10-26"), "2026-10-26");
  assert.equal(daily.isoWeekMonday("2027-01-01"), "2026-12-28");
});

test("flags come from the last ping date alone", () => {
  assert.deepEqual(daily.dailyFlags(null, "2026-10-25", false), { first: true, daily: true, weekly: true, monthly: true });
  assert.deepEqual(daily.dailyFlags(null, "2026-10-25", true), { first: false, daily: true, weekly: true, monthly: true });
  assert.equal(daily.dailyFlags("2026-10-25", "2026-10-25", false), null);
  assert.equal(daily.dailyFlags("2026-10-26", "2026-10-25", false), null);
  assert.deepEqual(daily.dailyFlags("2026-10-24", "2026-10-25", false), { first: false, daily: true, weekly: false, monthly: false });
  assert.deepEqual(daily.dailyFlags("2026-10-25", "2026-10-26", false), { first: false, daily: true, weekly: true, monthly: false });
  assert.deepEqual(daily.dailyFlags("2026-10-31", "2026-11-01", false), { first: false, daily: true, weekly: false, monthly: true });
  assert.deepEqual(daily.dailyFlags("garbage", "2026-10-25", false), { first: true, daily: true, weekly: true, monthly: true });
});

test("days are UTC and the recheck lands just after UTC midnight or within the hour", () => {
  assert.equal(daily.utcDay(Date.parse("2026-10-25T23:59:59-05:00")), "2026-10-26");
  assert.equal(daily.nextCheckDelay(Date.parse("2026-10-25T23:50:00Z"), 0), 10 * 60_000);
  assert.equal(daily.nextCheckDelay(Date.parse("2026-10-25T10:00:00Z"), 0), 60 * 60_000);
  assert.deepEqual([1, 2, 3, 10].map(daily.retryDelay), [60_000, 120_000, 240_000, 3_600_000]);
});

test("daily pings stay local for every sharing and instance setting", async () => {
  const { post, takePostStats, mayPost } = await import("./transport.ts");
  const { reloadLaunchConfigForTests } = await import("../../platform/launchConfig.ts");
  for (const development of [false, true]) {
    globalThis.__DEV__ = development;
    for (const isolated of [false, true]) for (const sharing of [false, true]) {
      reset(null);
      appInfo().isolatedInstance = isolated;
      stub.docs.set("telemetry.json", JSON.stringify({ version: 1, sharing, installId: "saved-id" }));
      stub.launch.test = { telemetry: "1" };
      reloadLaunchConfigForTests();
      for (const kind of ["daily", "events", "logs"]) {
        assert.equal(mayPost(kind), false);
        assert.equal(await post(kind, "{}", 1), 200);
      }
      assert.equal(await daily.sendDailyPing(at("2026-10-25")), "sent");
      assert.equal(await daily.sendDailyPing(at("2026-10-25")), "already");
      assert.deepEqual(daily.readDailyState(), { lastDay: "2026-10-25", pending: [] });
      assert.equal(posts.length, 0);
      assert.deepEqual(takePostStats(), { bytes: 0, failed: 0, requests: 0 });
    }
  }
  globalThis.__DEV__ = false;
  appInfo().isolatedInstance = false;
});

test("saved pending pings drain locally after relaunch, without retries or a request", async () => {
  reset("2026-10-24", true);
  const ping = { day: "2026-10-24", id: "pending-id", timestamp: "2026-10-24T12:00:00Z", properties: {} };
  stub.docs.set(daily.DAILY_DOC, JSON.stringify({ version: 1, lastDay: "2026-10-24", pending: [ping] }));
  status = 503;
  daily.resetDailyForTests(true);
  assert.equal(await daily.sendDailyPing(at("2026-10-25")), "sent");
  assert.deepEqual(daily.readDailyState(), { lastDay: "2026-10-25", pending: [] });
  assert.equal(await daily.sendDailyPing(at("2026-10-20")), "already");
  assert.equal(posts.length, 0);
});

test("a failed local save leaves daily state unchanged and sends nothing", async () => {
  reset(null);
  const set = stub.docs.set;
  stub.docs.set = () => { throw new Error("disk full"); };
  try { assert.equal(await daily.sendDailyPing(at("2026-10-25")), "failed"); }
  finally { stub.docs.set = set; }
  assert.equal(posts.length, 0);
  assert.equal(daily.readLastDay(), null);
});
