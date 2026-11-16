import assert from "node:assert/strict";
import { test } from "node:test";
import { ALLOWED_TEST, assessTests, parseOptions, standinReport } from "./report.mjs";
import { checkNetworkConnection } from "./rows.mjs";
import { assertNoJavaScriptException } from "./settings-tour.mjs";
import { AD_PATH, DOWNLOAD, startFixture } from "./fixture.mjs";

const totals = (pass, fail) => `1..${pass + fail}\n# tests ${pass + fail}\n# pass ${pass}\n# fail ${fail}\n# cancelled 0\n# skipped 0\n`;
const failure = (name = ALLOWED_TEST, path = "src/state/telemetry/watch.test.mjs") => `not ok 2 - ${name}\n  ---\n  location: '${path}:27:1'\n  code: 'ERR_ASSERTION'\n  expected: 'FB-1001'\n  operator: 'strictEqual'\n  ...\n`;

test("JS baseline accepts success or only the exact known failure", () => {
  assert.match(assessTests(0, totals(2, 0)), /2\/2/);
  assert.match(assessTests(1, failure() + totals(2267, 1)), /only allowed/);
  assert.throws(() => assessTests(1, failure("different failure") + totals(1, 1)));
  assert.throws(() => assessTests(1, failure(ALLOWED_TEST, "different.test.mjs") + totals(1, 1)));
  assert.throws(() => assessTests(1, failure().replace("FB-1001", "unexpected") + totals(1, 1)));
  assert.throws(() => assessTests(1, failure() + failure("another") + totals(1, 2)));
  assert.throws(() => assessTests(null, failure() + totals(1, 1)));
  assert.throws(() => assessTests(0, totals(2, 0).replace("# skipped 0", "# skipped 1")));
  assert.throws(() => assessTests(1, "process crashed"));
});

test("row selection rejects missing, unknown, and repeated rows", () => {
  const names = ["chromium", "smoke-g"];
  assert.deepEqual(parseOptions([], names), { build: true, rows: names });
  assert.deepEqual(parseOptions(["--no-build", "--only", "smoke-g"], names), { build: false, rows: ["smoke-g"] });
  for (const args of [["--only"], ["--only", "missing"], ["--other"], ["--only", "smoke-g", "--only", "chromium"]]) assert.throws(() => parseOptions(args, names));
});

test("stand-in report keeps unhit methods and counts categories over launches", () => {
  const source = `@implementation Example
+ (BOOL)ready { NSLog(@"[standin] %s", __PRETTY_FUNCTION__); return {}; }
+ (void (^)(void))handler { NSLog(@"[standin] %s", __PRETTY_FUNCTION__); return {}; }
- (void)fetch:(NSString *)name
    completion:(void (^)(BOOL))completion { NSLog(@"[standin] %s", __PRETTY_FUNCTION__); }
@end`;
  const report = standinReport([source], ["[standin] +[Example ready]", "[standin] +[Example(Launch) ready]\n[standin] -[Example fetch:completion:]"], ["smoke-g"]);
  assert.match(report, /3 stand-ins; 2 hit; 3 logged hits/);
  assert.match(report, /\+\[Example handler\]` \|  \| 0/);
  assert.match(report, /\+\[Example ready\]` \| yes \| 2/);
  assert.match(report, /-\[Example fetch:completion:\]` \| yes \| 1/);
  assert.throws(() => standinReport([source], ["[standin] +[Missing method]"], []));
});

test("local fixtures serve navigations, popups, a download, and a reachable ad control", async () => {
  const fixture = await startFixture();
  try {
    const html = await (await fetch(fixture.origin + "/one")).text();
    assert.match(html, /<title>Cobalt Violet one<\/title>/);
    assert.match(html, /target="_blank"/); assert.match(html, /window.open/);
    const download = await fetch(fixture.origin + "/download");
    assert.match(download.headers.get("content-disposition"), /smoke.txt/);
    assert.equal(await download.text(), DOWNLOAD);
    assert.equal((await fetch(fixture.origin + AD_PATH)).status, 200);
    assert.ok(fixture.hits.includes(AD_PATH));
    assert.equal((await fetch(fixture.origin + "/favicon.ico")).status, 404);
  } finally { await fixture.close(); }
});

test("network absence is offline, HTTP errors fail, and successful preflight completes", async (context) => {
  const request = context.mock.method(globalThis, "fetch", async () => { throw new TypeError("fetch failed", { cause: { code: "ENETUNREACH" } }); });
  await assert.rejects(checkNetworkConnection("https://fixture.invalid/"), (error) => error.offline && /skipped \(offline\)/.test(error.message));
  request.mock.mockImplementation(async () => ({ ok: false, status: 429 }));
  await assert.rejects(checkNetworkConnection("https://fixture.invalid/"), (error) => !error.offline && /HTTP 429/.test(error.message));
  request.mock.mockImplementation(async () => ({ ok: true, arrayBuffer: async () => new ArrayBuffer(0) }));
  await checkNetworkConnection("https://fixture.invalid/");
});

test("settings tour rejects logged JS exceptions, including caught exceptions", () => {
  assertNoJavaScriptException("2026-11-16 warn Legacy Architecture is deprecated\n");
  for (const line of ["2026-11-16 error failed", "TypeError: Cannot read property 'ready' of undefined", "2026-11-16 warn list failed ReferenceError: missing", "Unhandled JS Exception", "ArdiaError: the reply is not JSON"]) {
    assert.throws(() => assertNoJavaScriptException(line), /JS exception/);
  }
});

test("foreground session lock and nonfailure result states stay distinct", async () => {
  const {screenIsLocked,resultFails} = await import("./report.mjs");
  assert.equal(screenIsLocked([{IOConsoleUsers:[{CGSSessionScreenIsLocked:true}]}]),true);
  assert.equal(screenIsLocked([{IOConsoleUsers:[{CGSSessionScreenIsLocked:false}]}]),false);
  assert.equal(screenIsLocked([{}]),false);
  assert.equal(screenIsLocked([{CGSSessionScreenIsLocked:1}]),true);
  for(const status of ["PASS","NEEDS PERSON","SKIPPED (screen locked)"]) assert.equal(resultFails(status),false);
  for(const status of ["FAIL","skipped (offline)","unknown"]) assert.equal(resultFails(status),true);
});
