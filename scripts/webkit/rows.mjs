import { passwordNative, passwordRows } from "./password-rows.mjs";
import { importRows } from "./import-rows.mjs";
import { bookmarkRows } from "./bookmark-rows.mjs";
import { settingsRows } from "./settings-rows.mjs";
import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { APP, BUILD, run, sleep } from "./support.mjs";
import { binaryOf, isAlive } from "../lib/instance.mjs";
import { AD_PATH, DOWNLOAD, titleOf } from "./fixture.mjs";
import { pageRows } from "./page-rows.mjs";
import { windowRows } from "./window-rows.mjs";
import { settingsTour } from "./settings-tour.mjs";
import { ALLOWED_TEST, assessTests } from "./report.mjs";

class Offline extends Error { constructor(message) { super(message); this.offline = true; } }
export async function checkNetworkConnection(url) {
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(15000) });
    assert.ok(response.ok, `network preflight returned HTTP ${response.status}`);
    await response.arrayBuffer();
  } catch (error) {
    const code = error.cause?.code;
    if (["ENETUNREACH", "EHOSTUNREACH", "ENOTFOUND", "EAI_AGAIN", "UND_ERR_CONNECT_TIMEOUT"].includes(code) || error.name === "TimeoutError") throw new Offline(`skipped (offline): ${code ?? error.name}`);
    throw error;
  }
}

async function visitThree(browser) {
  const id = await browser.open("/one");
  for (const name of ["one", "two", "three"]) {
    const url = `${browser.fixture.origin}/${name}`;
    if (name !== "one") await browser.evaluate(`ac.store.getState().navigate(${JSON.stringify(id)},${JSON.stringify(url)});return true;`);
    await browser.loaded(id, titleOf("/" + name));
    await browser.until(`return ac.engine.call("history.query",{profile:"",maxUrls:5000,maxVisits:50}).then(r=>r.entries.some(e=>e.u===${JSON.stringify(url)}&&e.t===${JSON.stringify(titleOf("/" + name))}));`);
  }
  return id;
}

async function terminate(browser) {
  const file = join(browser.data, "quit-evidence.json");
  await browser.evaluate('ac.shell.onAppEvent(e=>{if(e.type==="willQuit")ac.shell.writeDocument("quit-evidence.json",JSON.stringify(e));});return true;');
  const started = Date.now();
  await browser.requestQuit();
  for (const end = started + 10000; Date.now() < end && isAlive(browser.app.pid); await sleep(50));
  assert.ok(!isAlive(browser.app.pid), "terminate handler did not end the app within 10 seconds");
  assert.ok(existsSync(file), "terminate handler did not emit willQuit");
  assert.equal(JSON.parse(readFileSync(file, "utf8")).type, "willQuit");
  return `willQuit observed; exited in ${Date.now() - started} ms (<10000 ms)`;
}

export const rows = {
  ...passwordRows,
  ...importRows,
  ...bookmarkRows,
  ...settingsRows,
  ...pageRows,
  ...windowRows,
  "settings-tour": settingsTour,
  "no-upstream": async ({ browser, fixture }) => {
    const requests = () => existsSync(join(browser.data, "requests.jsonl")) ? readFileSync(join(browser.data, "requests.jsonl"), "utf8").trim().split("\n").filter(Boolean).map(JSON.parse) : [];
    const evidence = join(BUILD, "step-1-evidence");
    mkdirSync(evidence, { recursive: true });
    try {
      const jsControl = fixture.origin + "/observe-js";
      const nativeControl = fixture.origin + "/observe-native";
      assert.equal(await browser.evaluate(`return fetch(${JSON.stringify(jsControl)}).then(r=>r.status);`), 200);
      const native = await browser.evaluate(`return ac.engine.call("search.suggest",{profile:"",id:9001,url:${JSON.stringify(nativeControl)}});`);
      assert.equal(native.status, 200);
      for (const url of [jsControl, nativeControl]) {
        assert.ok(requests().some(r => r.url === url && r.pid === browser.app.pid), `observer missed ${url}`);
        assert.ok(fixture.hits.includes(new URL(url).pathname), "control never reached fixture");
      }
      await browser.until('const o=ac.onboarding.useOnboarding.getState();return o.windowId&&o.step==="look";');
      assert.deepEqual(await browser.evaluate('return ac.onboarding.activeSteps();'), ["look"]);
      await browser.evaluate('ac.onboarding.confirmAnswer("look",{},[]);return true;');
      await browser.until('return ac.onboarding.onboardingCompletedAt()&&!ac.onboarding.useOnboarding.getState().windowId;');
      const id = await browser.open("/after-onboarding");
      assert.equal(await browser.page(id, "document.title"), titleOf("/after-onboarding"));
      await browser.snapshot("after-onboarding.png");
      copyFileSync(join(browser.data, "after-onboarding.png"), join(evidence, "after-onboarding.png"));
      const before = await browser.evaluate('return ac.engine.call("windows.list").then(w=>w.map(w=>w.window));');
      await browser.evaluate('ac.store.getState().updateSettings({showAdvancedSettings:true});ac.openSettings("general");return true;');
      const settingsWindow = await browser.until(`return ac.engine.call("windows.list").then(w=>w.find(w=>w.hasRoot&&!${JSON.stringify(before)}.includes(w.window))?.window);`);
      for (const pane of ["general", "privacy"]) {
        await browser.evaluate(`ac.openSettings(${JSON.stringify(pane)});return true;`);
        await sleep(1000);
        await browser.snapshot(`settings-${pane}.png`, settingsWindow);
        copyFileSync(join(browser.data, `settings-${pane}.png`), join(evidence, `settings-${pane}.png`));
      }
      while (Date.now() - browser.started < 90000) {
        assert.ok(browser.app.alive, "app died during observation");
        await sleep(Math.min(1000, 90000 - (Date.now() - browser.started)));
      }
      await browser.stop();
      const observed = requests();
      const urls = [...new Set(observed.map(r => r.url))];
      assert.ok(observed.every(r => r.pid === browser.app.pid), "unexpected process in request observation");
      assert.ok(urls.every(url => new URL(url).origin === fixture.origin), `non-fixture requests: ${JSON.stringify(urls)}`);
      return `90 seconds; onboarding completed; JS and native controls observed; requests=${JSON.stringify(urls)}; snapshots=${evidence}`;
    } catch (error) {
      throw new Error(`${error.message}; observed requests=${JSON.stringify([...new Set(requests().map(r => r.url))])}`);
    } finally {
      writeFileSync(join(evidence, "requests.json"), JSON.stringify({ pid: browser.app.pid, milliseconds: Date.now() - browser.started, urls: [...new Set(requests().map(r => r.url))] }, null, 2) + "\n");
      for (const [source, name] of [[browser.app.log, "app.log"], [join(browser.data, "dev-console.log"), "dev-console.log"]]) {
        if (existsSync(source)) copyFileSync(source, join(evidence, name));
      }
    }
  },
  chromium: async () => {
    const libraries = await run("otool", ["-L", binaryOf(APP)]);
    const linked = libraries.text.split("\n").filter((line) => /chromium/i.test(line)).length;
    const bundled = (await run("find", [APP, "-iname", "*chromium*"])).text.trim().split("\n").filter(Boolean).length;
    assert.equal(linked, 0, "Chromium is linked"); assert.equal(bundled, 0, "Chromium is bundled");
    return `otool=${linked}; bundle=${bundled}`;
  },
  sign: async ({ scratch }) => {
    await run("codesign", ["--verify", "--deep", "--strict", APP]);
    const { text } = await run("codesign", ["-dv", "--entitlements", "-", APP]);
    assert.match(text, /Signature=adhoc/);
    const plist = text.match(/<\?xml[\s\S]*?<\/plist>/)?.[0];
    if (plist) {
      const { writeFileSync } = await import("node:fs");
      const file = join(scratch, "entitlements.plist"); writeFileSync(file, plist);
      const json = await run("plutil", ["-convert", "json", "-o", "-", file]);
      assert.deepEqual(JSON.parse(json.text), {}, "app carries entitlements");
    }
    return "deep signature valid; ad hoc; entitlements=0";
  },
  "smoke-a": async ({ browser }) => {
    assert.ok(existsSync(join(APP, "Contents/Resources/main.jsbundle")), "Release JS bundle is missing");
    await browser.type(browser.fixture.origin + "/typed"); await browser.submit();
    const id = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet typed")?.id;');
    await browser.loaded(id, "Cobalt Violet typed");
    const title = await browser.page(id, "document.title"); assert.equal(title, "Cobalt Violet typed");
    assert.ok((await browser.snapshot()).bytes > 1000, "window snapshot is empty");
    return `bundled JS; window snapshot valid; typed URL title=${title}`;
  },
  "smoke-b": async ({ browser }) => {
    const ids = [];
    for (let i = 0; i < 5; i++) ids.push(await browser.open(`/tab-${i}`));
    for (const id of ids) {
      await browser.activate(id);
      assert.equal(await browser.evaluate(`const s=ac.store.getState();return s.windows[${JSON.stringify(browser.window)}].activeTabIds.default;`), id);
      assert.equal(await browser.page(id, "document.title"), titleOf(`/tab-${ids.indexOf(id)}`));
    }
    const closed = ids[4];
    await browser.evaluate(`ac.store.getState().closeTab(${JSON.stringify(closed)});return true;`);
    assert.equal(await browser.evaluate(`return !!ac.store.getState().tabs[${JSON.stringify(closed)}];`), false);
    await browser.evaluate(`ac.runCommand({command:"reopenClosedTab",arg:null,windowId:${JSON.stringify(browser.window)}});return true;`);
    const restored = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet tab-4")?.id;');
    await browser.loaded(restored, titleOf("/tab-4"));
    assert.equal(await browser.evaluate(`return ac.store.getState().windows[${JSON.stringify(browser.window)}].tabIds.length;`), 5);
    return "5 opened; 5 switched; closed tab absent; reopened title correct; 5 remain";
  },
  "smoke-c": async ({ browser }) => {
    const id = await browser.open("/first");
    await browser.execute(id, "document.querySelector('#next').click()"); await browser.loaded(id, titleOf("/second"));
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).goBack();`); await browser.loaded(id, titleOf("/first"));
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).goForward();`); await browser.loaded(id, titleOf("/second"));
    await browser.page(id, '(document.documentElement.dataset.reloadMarker="set")');
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).reload();`);
    await browser.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(document.documentElement.dataset.reloadMarker??null));').then(v=>v===null);`);
    await browser.loaded(id, titleOf("/second"));
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).find("needle",true,false);`);
    const found = await browser.until(`return ac.store.getState().find[${JSON.stringify(id)}]?.count===2;`); assert.equal(found, true);
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).zoomStep(1);`);
    const zoom = await browser.until(`const z=ac.store.getState().tabs[${JSON.stringify(id)}].zoom;return z>1?z:null;`);
    return `back, forward, reload verified; find=2; zoom=${zoom}`;
  },
  "smoke-d": async ({ browser }) => {
    const id = await browser.open();
    await browser.execute(id, "document.querySelector('#blank').click()");
    const blank = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet blank")?.id;');
    await browser.loaded(blank, titleOf("/blank")); await browser.activate(id);
    await browser.execute(id, "document.querySelector('#popup').click()");
    const popup = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet popup")?.id;');
    await browser.loaded(popup, titleOf("/popup")); assert.notEqual(blank, popup);
    assert.equal(await browser.evaluate('return ac.store.getState().windowOrder.length;'), 1);
    return "target=_blank and window.open each loaded a new tab; windows=1";
  },
  "smoke-e": async ({ browser }) => {
    const id = await browser.open();
    await browser.evaluate('globalThis.webkitDownloads=[];ac.engine.on("downloads.changed",e=>globalThis.webkitDownloads.push(e));return true;');
    await browser.execute(id, "document.querySelector('#download').click()");
    const item = await browser.until('return globalThis.webkitDownloads.find(d=>d.state==="finished");');
    assert.equal(item.path, join(browser.data, "downloads/smoke.txt"), "unexpected download path");
    assert.equal(readFileSync(item.path, "utf8"), DOWNLOAD); assert.equal(item.received, Buffer.byteLength(DOWNLOAD));
    return `finished; scratch/downloads/smoke.txt; ${item.received} bytes; contents match`;
  },
  "smoke-f": async ({ browser }) => {
    await browser.open();
    const second = await browser.evaluate(`return ac.store.getState().createWindow({url:${JSON.stringify(browser.fixture.origin + "/second-window")}});`);
    const id = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(second)}&&t.title==="Cobalt Violet second-window")?.id;`);
    await browser.loaded(id, titleOf("/second-window"));
    await browser.until('return ac.shell.windowIds().then(ids=>ids.length===2);');
    await browser.evaluate(`ac.store.getState().closeWindow(${JSON.stringify(second)});return true;`);
    await browser.until('return ac.shell.windowIds().then(ids=>ids.length===1);');
    await browser.evaluate(`ac.store.getState().closeWindow(${JSON.stringify(browser.window)});return true;`);
    await browser.until('return ac.shell.windowIds().then(ids=>ids.length===0);'); await sleep(500);
    assert.ok(browser.app.alive); assert.equal(await browser.evaluate('return ac.store.getState().windowOrder.length;'), 0);
    return "native windows: 2 -> 1 -> 0; app and harness remain alive";
  },
  "smoke-g": async ({ browser }) => { await browser.open(); return terminate(browser); },
  "smoke-h": async ({ browser }) => {
    await browser.open("/restored-one");
    await browser.open("/restored-two");
    const second = await browser.evaluate(`return ac.store.getState().createWindow({url:${JSON.stringify(browser.fixture.origin + "/restored-three")}});`);
    const third = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(second)}&&t.title==="Cobalt Violet restored-three")?.id;`);
    await browser.loaded(third, titleOf("/restored-three"));
    const state = 'const s=ac.store.getState();return {windows:s.windowOrder.length,urls:Object.values(s.tabs).map(t=>t.url).sort()};';
    const before = await browser.evaluate(state); assert.equal(before.windows, 2); assert.equal(before.urls.length, 3);
    await terminate(browser); await browser.launch();
    assert.deepEqual(await browser.evaluate(state), before);
    await browser.until('return ac.shell.windowIds().then(ids=>ids.length===2);');
    return "same data dir restored 2 windows and all 3 tab URLs";
  },
  "smoke-i": async ({ browser }) => {
    const personal = await browser.open("/cookies");
    const profile = await browser.evaluate('return ac.store.getState().createProfile({name:"Smoke Work"});');
    const window = await browser.evaluate(`return ac.store.getState().createWindow({profileId:${JSON.stringify(profile)},url:${JSON.stringify(browser.fixture.origin + "/cookies")}});`);
    const other = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(window)}&&t.title==="Cobalt Violet cookies")?.id;`);
    await browser.loaded(other, titleOf("/cookies"));
    await browser.page(personal, '(document.cookie="smoke=personal; path=/",document.cookie)');
    const mine = await browser.page(personal, "document.cookie"), theirs = await browser.page(other, "document.cookie");
    assert.ok(mine.includes("smoke=personal")); assert.ok(!theirs.includes("smoke=personal"));
    await browser.page(other, '(document.cookie="smoke=work; path=/",document.cookie)');
    assert.ok((await browser.page(other, "document.cookie")).includes("smoke=work"));
    assert.ok((await browser.page(personal, "document.cookie")).includes("smoke=personal"));
    return "personal cookie=personal; second profile initially empty, then cookie=work; first unchanged";
  },
  "smoke-j": async ({ browser }) => {
    const first = await browser.open("/split-one"), second = await browser.open("/split-two");
    const split = await browser.evaluate(`return ac.store.getState().createSplit([${JSON.stringify(first)},${JSON.stringify(second)}]);`); assert.ok(split);
    await browser.until(`return ac.webviews.has(${JSON.stringify(first)})&&ac.webviews.has(${JSON.stringify(second)});`);
    const pages = await Promise.all([first, second].map((id) => browser.page(id, "({title:document.title,width:innerWidth,height:innerHeight})")));
    assert.deepEqual(pages.map((p) => p.title), [titleOf("/split-one"), titleOf("/split-two")]);
    assert.ok(pages.every((p) => p.width > 0 && p.height > 0));
    return `two mounted pages with correct titles; widths=${pages.map((p) => p.width).join(",")}`;
  },
  "smoke-k": async ({ browser, fixture }) => {
    const id = await browser.open("/blocker");
    const state = await browser.until('return ac.engine.call("webKit.devContentBlocker").then(s=>s.ready&&s.lists>0?s:null);', 60000);
    assert.equal(state.error, null);
    assert.equal((await fetch(fixture.origin + AD_PATH)).status, 200);
    const previousHits = fixture.hits.filter((path) => path === AD_PATH).length;
    const before = await browser.evaluate(`return ac.pageState.getState().pages[${JSON.stringify(id)}]?.blocked??0;`);
    const load = (path) => browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).evaluate(${JSON.stringify(`const script=document.createElement("script");script.src=${JSON.stringify(fixture.origin + path)};script.onload=()=>post("result",JSON.stringify("loaded"));script.onerror=()=>post("result",JSON.stringify("blocked"));document.head.append(script);`)});`);
    assert.equal(await load("/control.js"), "loaded");
    assert.equal(await load(AD_PATH), "blocked");
    const blocked = await browser.until(`const n=ac.pageState.getState().pages[${JSON.stringify(id)}]?.blocked??0;return n>${before}?n:null;`);
    assert.equal(fixture.hits.filter((path) => path === AD_PATH).length, previousHits, "ad request reached the fixture");
    const settings = await browser.evaluate('return ac.engine.call("contentBlocker.state");');
    assert.equal(settings.enabled, state.enabled);
    assert.equal(settings.stats.ready, state.ready);
    assert.equal(settings.stats.blocked, blocked);
    assert.ok(settings.lists.some(list => list.id === "easylist" && list.enabled));
    return `bundled lists=${state.lists}; control loaded; local ad blocked; blocked count=${blocked}; server received no ad request`;
  },
  favicon: async ({ browser }) => {
    await checkNetworkConnection("https://www.python.org/static/favicon.ico");
    const id = await browser.open("https://www.python.org/");
    const resolve = `const t=ac.store.getState().tabs[${JSON.stringify(id)}];const f=ac.favicons.resolveFavicon(t.url,t.favicon,t.profileId);return f?.uri?{title:t.title,icon:t.favicon,uri:f.uri}:null;`;
    const before = await browser.until(resolve, 30000);
    assert.match(before.uri, /^data:image\/png;base64,/); assert.ok(before.icon);
    const query = 'return ac.engine.call("favicons.get",{profile:"",pages:["https://www.python.org/"],icons:[],size:32}).then(r=>r.pages["https://www.python.org/"]??null);';
    const saved = await browser.until(query);
    const snapshot = await browser.snapshot("favicon.png");
    await browser.restart();
    assert.equal((await browser.until(query)).png, saved.png);
    const after = await browser.until(resolve); assert.equal(after.uri, before.uri);
    return `Python icon=${before.uri.length} characters; same PNG and UI icon after relaunch; snapshot=${snapshot.width}x${snapshot.height}`;
  },
  history: async ({ browser }) => {
    await visitThree(browser); assert.equal((await browser.history()).entries.length, 3);
    await browser.restart(); await browser.type("Violet one");
    const item = await browser.until(`return ac.omnibox.get(${JSON.stringify(browser.driver)}).state().items.find(i=>i.kind==="page"&&i.visited&&i.title==="Cobalt Violet one");`);
    assert.equal(item.url, browser.fixture.origin + "/one");
    assert.equal(await browser.sql("SELECT COUNT(*) FROM pages;"), "3");
    const count = await browser.sql("SELECT COUNT(*) FROM visits;");
    return `3 distinct URLs persisted in WebKit/Stores/default.sqlite3 (${count} visits); partial title found Cobalt Violet one`;
  },
  "history-delete": async ({ browser }) => {
    await visitThree(browser);
    const old = (await browser.history()).entries;
    await browser.type("Violet one");
    const url = browser.fixture.origin + "/one";
    await browser.evaluate(`ac.store.getState().removeHistory("default",[${JSON.stringify(url)}]);return true;`);
    await browser.until(`return ac.engine.call("history.query",{profile:"",maxUrls:5000,maxVisits:50}).then(r=>!r.entries.some(e=>e.u===${JSON.stringify(url)}));`);
    await browser.until(`return !ac.omnibox.get(${JSON.stringify(browser.driver)}).state().items.some(i=>i.url===${JSON.stringify(url)});`);
    assert.equal(await browser.sql("SELECT COUNT(*) FROM pages WHERE url LIKE '%/one';"), "0");
    await browser.evaluate('return ac.engine.call("profiles.clearBrowsingData",{profile:"",types:["history"],since:0});');
    const replay = await browser.evaluate(`return ac.engine.call("history.add",{profile:"",pages:${JSON.stringify(old)},toleranceMs:0});`); assert.equal(replay.added, 0);
    await sleep(2000);
    assert.equal((await browser.history()).entries.length, 0); assert.equal(await browser.sql("SELECT COUNT(*) FROM visits;"), "0");
    assert.equal((await browser.suggestions()).filter((i) => i.visited).length, 0);
    return "deleted URL absent from suggestions and SQL; clear leaves 0 visits; delayed replay added=0";
  },
  "history-private": async ({ browser }) => {
    await visitThree(browser);
    const count = await browser.sql("SELECT COUNT(*) FROM visits;");
    const files = readdirSync(join(browser.data, "WebKit/Stores")).filter((name) => name.endsWith(".sqlite3"));
    const window = await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${JSON.stringify(browser.fixture.origin + "/private")}});`);
    const tab = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(window)}&&t.title==="Cobalt Violet private");`);
    await browser.loaded(tab.id, titleOf("/private")); await sleep(2000);
    const result = await browser.evaluate(`const s=ac.store.getState();return ac.engine.call("history.add",{profile:ac.model.engineProfile(s,${JSON.stringify(tab.profileId)}),pages:[{u:${JSON.stringify(browser.fixture.origin + "/private")},t:"Private",v:[Date.now()]}]});`);
    assert.equal(result.added, 0); assert.equal(await browser.sql("SELECT COUNT(*) FROM visits;"), count);
    assert.deepEqual(readdirSync(join(browser.data, "WebKit/Stores")).filter((name) => name.endsWith(".sqlite3")), files);
    return `private page loaded; visits ${count} -> ${count}; private native add=0; no extra store`;
  },
  search: async ({ browser }) => {
    await checkNetworkConnection("https://www.google.com/generate_204");
    await browser.evaluate('ac.store.getState().updateSettings({searchSuggestions:true});return true;');
    await browser.type("weath");
    const suggestions = await browser.until(`const d=ac.omnibox.get(${JSON.stringify(browser.driver)});const list=d.state().items.filter(i=>i.suggested);return list.length?list:null;`, 30000);
    await browser.type("weather in Prague"); await browser.submit();
    const id = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.url.includes("google.com/search?q=weather%20in%20Prague"))?.id;', 30000);
    await browser.loaded(id);
    const page = await browser.page(id, "({url:location.href,title:document.title})");
    assert.equal(new URL(page.url).searchParams.get("q"), "weather in Prague"); assert.ok(page.title);
    return `weath -> ${suggestions.length} network suggestions (${suggestions[0].query}); typed query loaded Google results`;
  },
  native: async ({ scratch }) => {
    const pageExecutable = join(scratch, "page-check");
    const bookmarkObject = join(scratch, "page-bookmarks.o");
    const storeObject = join(scratch, "page-store.o"), hostObject = join(scratch, "page-host.o");
    for (const [source, output] of [["packages/ardiacore/ios/webkit/Bookmarks.mm", bookmarkObject], ["packages/ardiacore/ios/webkit/Store.mm", storeObject], ["packages/ardiacore/tests/webkit-page-store.mm", hostObject]]) {
      await run("xcrun", ["clang++", "-std=c++20", "-fobjc-arc", "-fblocks", "-c", source, "-o", output]);
    }
    await run("xcrun", ["swiftc", "-import-objc-header", "packages/ardiacore/ios/ArdiaServices.h", storeObject, bookmarkObject, hostObject, "-lsqlite3", "-lc++", "packages/ardiacore/tests/webkit-page.test.swift", "packages/ardiacore/ios/WebKitPageScript.swift", "packages/ardiacore/ios/WebKitStores.swift", "-o", pageExecutable]);
    const pageDirectory = join(scratch, "page-native");
    mkdirSync(pageDirectory, {recursive:true});
    const pageResult = await run(pageExecutable, [pageDirectory], {env:{ARDIA_DATA_DIR:pageDirectory}});
    const executable = join(scratch, "native-check");
    await run("xcrun", ["clang++", "-std=c++20", "-fobjc-arc", "-fblocks", "-Wno-incomplete-implementation", "-framework", "AppKit", "-framework", "Security", "-lsqlite3",
      "packages/ardiacore/tests/webkit-data.test.mm", "packages/ardiacore/tests/webkit-bookmarks.test.mm", "packages/ardiacore/ios/ArdiaLaunchConfig.mm", ...["Store", "Bookmarks", "Network", "Favicons", "Services", "EngineBridge"].map((name) => `packages/ardiacore/ios/webkit/${name}.mm`), "-o", executable]);
    const windowExecutable = join(scratch, "window-check");
    await run("xcrun", ["clang++", "-std=c++20", "-fobjc-arc", "-fblocks", "-Wno-incomplete-implementation", "-framework", "AppKit", "-framework", "WebKit", "-framework", "QuartzCore", "-framework", "Security", "-lsqlite3",
      "packages/ardiacore/tests/webkit-window.test.mm", "packages/ardiacore/ios/ArdiaLaunchConfig.mm", ...["Host", "Store", "Bookmarks", "Network", "Services"].map(name => `packages/ardiacore/ios/webkit/${name}.mm`), "-o", windowExecutable]);
    const windowResult = await run(windowExecutable, [], {env: {ARDIA_DATA_DIR:scratch,ARDIA_BACKGROUND:"1"}});
    const passwords = await passwordNative(scratch);
    return passwords+"; "+(await run(executable, [scratch], { env: { ARDIA_DATA_DIR: scratch, ARDIA_TEST: "networkRequests" } })).text.trim()+"; "+windowResult.text.trim()+"; "+pageResult.text.trim();
  },
  js: async ({ scratch }) => {
    await run(process.execPath, ["--test", "scripts/webkit/check.test.mjs"]);
    const tests = await run("pnpm", ["--filter", "@ardia/browser", "test"], { log: join(scratch, "js-tests.log"), env: { NODE_OPTIONS: "--test-reporter=tap" }, allowFailure: true });
    await run("pnpm", ["--filter", "@ardia/browser", "typecheck"], { log: join(scratch, "typecheck.log") });
    try { return assessTests(tests.status, tests.text); }
    catch (error) {
      const failures = [...tests.text.matchAll(/^not ok \d+ - [^\n]+\n[\s\S]*?(?=^(?:ok |not ok |1\.\.|# tests )|(?![\s\S]))/gm)].map((match) => match[0]).join("\n");
      throw new Error(`${error.message}\n${failures || tests.text.slice(-6000)}`);
    }
  },
};
export const browserRows = new Set(Object.keys(rows).filter((name) => !name.startsWith("import-") && !["chromium", "sign", "native", "js"].includes(name)));
export { ALLOWED_TEST };
