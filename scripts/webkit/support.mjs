import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { closeSync, existsSync, mkdirSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { attach, binaryOf, binaryPids, isAlive, processInfo, sleep } from "../lib/instance.mjs";
import { tmpdir } from "node:os";
import { RowOutcome, screenIsLocked } from "./report.mjs";
import { titleOf } from "./fixture.mjs";

export const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
export const BUILD = join(ROOT, "apps/browser/build-webkit");
export const APP = join(BUILD, "Build/Products/Release/Ardia WebKit.app");
export const ZIP = join(BUILD, "Ardia-WebKit-Release.zip");
export { sleep };

export async function run(command, args, { log, timeout = 600000, env = {}, allowFailure = false } = {}) {
  const output = log ? openSync(log, "w") : null;
  let text = "";
  let timedOut = false;
  const child = spawn(command, args, { cwd: ROOT, env: { ...process.env, ...env }, detached: true, stdio: ["ignore", output ?? "pipe", output ?? "pipe"] });
  const terminate = (signal) => { try { process.kill(-child.pid, signal); } catch {} };
  const stop = () => terminate("SIGTERM");
  process.once("SIGINT", stop); process.once("SIGTERM", stop);
  let force;
  const timer = setTimeout(() => { timedOut = true; stop(); force = setTimeout(() => terminate("SIGKILL"), 3000); }, timeout);
  if (!log) {
    child.stdout.on("data", (data) => { text += data; });
    child.stderr.on("data", (data) => { text += data; });
  }
  let status;
  try {
    status = await new Promise((resolve, reject) => { child.once("error", reject); child.once("close", (code) => resolve(code)); });
  } finally {
    clearTimeout(timer); clearTimeout(force);
    process.removeListener("SIGINT", stop); process.removeListener("SIGTERM", stop);
    if (output !== null) closeSync(output);
  }
  if (log) text = readFileSync(log, "utf8");
  if (timedOut || (status !== 0 && !allowFailure)) throw new Error(`${command}: ${timedOut ? "timed out" : `exit ${status}`}\n${text.slice(-10000)}`);
  return { status, text };
}

export class Browser {
  constructor(directory, fixture, launches, options = {}) {
    this.options = options;
    this.data = directory;
    this.fixture = fixture;
    this.launches = launches;
    this.store = join(directory, "WebKit/Stores/default.sqlite3");
  }
  async launch() {
    if (this.options.foreground) {
      const session = await run("ioreg", ["-n", "Root", "-d1", "-a"]);
      const converted = spawnSync("plutil", ["-convert", "json", "-o", "-", "-"], {input:session.text, encoding:"utf8"});
      assert.equal(converted.status,0,"cannot decode GUI session state");
      if (screenIsLocked(JSON.parse(converted.stdout))) throw new RowOutcome("SKIPPED (screen locked)","foreground row requires an unlocked session");
      this.foregroundLock = join(tmpdir(),"ardia-webkit-foreground.lock");
      const lock = openSync(this.foregroundLock,"wx");
      closeSync(lock);
      this.ownsForegroundLock = true;
    }
    this.driver = null;
    mkdirSync(join(this.data, "downloads"), { recursive: true });
    writeFileSync(join(this.data, "perf-probe"), "");
    if (!this.options.onboarding) writeFileSync(join(this.data, "onboarding.json"), JSON.stringify({ version: 1, completedAt: 1 }));
    for (const file of ["dev-eval.js", "dev-eval-result.json", "modal-alert.json"]) rmSync(join(this.data, file), { force: true });
    if (this.options.observe) writeFileSync(join(this.data, "telemetry.json"), JSON.stringify({version:1,sharing:true,installId:"webkit-check",decidedAt:1,askDoneAt:1}));
    const binary = binaryOf(APP);
    const before = binaryPids(binary);
    const log = join(this.data, `launch-${this.launches.length + 1}.log`);
    this.started = Date.now();
    const launched = spawnSync("open", [...(this.options.foreground ? ["-n"] : ["-g", "-n"]), "--stdout", log, "--stderr", log,
      ...(this.options.foreground ? [] : ["--env", "ARDIA_BACKGROUND=1"]), "--env", `ARDIA_DATA_DIR=${this.data}`,
      "--env", `ARDIA_TEST=keychain=file${this.options.observe ? ",networkRequests" : ""}`, "--env", `ARDIA_INSTANCE=downloadsDir=${join(this.data, "downloads")},syncFolder=${join(this.data, "sync")},sharedFolders=${join(this.data, "shared")}`, APP], { encoding: "utf8", timeout: 10000, env: Object.fromEntries(Object.entries(process.env).filter(([key]) => key !== "ARDIA_BACKGROUND")) });
    assert.equal(launched.status, 0, launched.stderr);
    let pid;
    for (const end = Date.now() + 10000; Date.now() < end && !pid; await sleep(100)) {
      const candidates = [...binaryPids(binary)].filter((candidate) => !before.has(candidate));
      assert.ok(candidates.length <= 1, "multiple new app processes; ownership is ambiguous");
      [pid] = candidates;
    }
    assert.ok(pid, "no process appeared after hidden launch");
    const record = { pid, binary, started: processInfo(pid).started, data: this.data, log };
    writeFileSync(join(this.data, "instance.json"), JSON.stringify(record));
    this.app = attach(this.data);
    this.launches.push(this.app);
    await this.app.ready({ timeout: 30000 });
    await this.evaluate('ac.store.getState().updateSettings({searchSuggestions:false});return true;');
    this.window = await this.until('return ac.store.getState().windowOrder[0];');
    await this.until(`return ac.shell.windowIds().then(ids=>ids.includes(${JSON.stringify(this.window)}));`);
    if (this.options.foreground) {
      await this.evaluate('return ac.engine.call("windows.list").then(w=>ac.engine.call("windows.dev",{window:w.find(w=>w.hasRoot).window,action:"activate"}));');
      try { await this.until('return ac.engine.call("windows.list").then(w=>w.some(w=>w.key));',10000); }
      catch(error) {
        const path=join(this.data,"activation.json");
        throw new RowOutcome("SKIPPED (no key window)",`this session cannot make the app active; activation=${existsSync(path)?readFileSync(path,"utf8"):"callback did not run"}`);
      }
    }
    return this;
  }
  assertNoModalAlert() {
    const path = join(this.data,"modal-alert.json");
    if (existsSync(path)) throw new Error(`app-modal alert: ${readFileSync(path,"utf8")}`);
  }
  async evaluate(body, timeout = 10000) {
    this.assertNoModalAlert();
    try { const value = await this.app.eval(body, { timeout }); this.assertNoModalAlert(); return value; }
    catch (error) { throw new Error(`${error.message}; eval: ${body.slice(0, 600)}`); }
  }
  async until(body, timeout = 20000) {
    let last;
    for (const end = Date.now() + timeout; Date.now() < end; await sleep(150)) {
      last = await this.evaluate(body, Math.min(10000, Math.max(500, end - Date.now())));
      if (last) return last;
    }
    throw new Error(`Timed out: ${body}; last=${JSON.stringify(last)}`);
  }
  async requestQuit() {
    return this.app.eval('return ac.engine.call("windows.devQuit");',{timeout:3000});
  }
  async stop() {
    try {
      if (!this.app?.alive) return;
      try { await this.requestQuit(); } catch {}
      for (const end=Date.now()+10000;Date.now()<end&&this.app.alive;await sleep(100));
      if (this.app.alive) {
        this.app.kill("SIGTERM");
        for(const end=Date.now()+3000;Date.now()<end&&this.app.alive;await sleep(100));
        if(this.app.alive) {
          this.app.kill("SIGKILL");
          for(const end=Date.now()+1000;Date.now()<end&&this.app.alive;await sleep(100));
        }
        throw new Error("in-app quit timed out; owned instance terminated");
      }
      for(const end=Date.now()+3000;Date.now()<end&&isAlive(this.app.pid);await sleep(100));
      assert.ok(!isAlive(this.app.pid),"app survived cleanup");
    } finally {
      if(this.ownsForegroundLock) { rmSync(this.foregroundLock,{force:true}); this.ownsForegroundLock=false; }
      this.assertNoModalAlert();
    }
  }
  async restart() { await this.stop(); return this.launch(); }
  async open(path = "/first", { window = this.window } = {}) {
    const url = path.startsWith("http") ? path : this.fixture.origin + path;
    const id = await this.evaluate(`const s=ac.store.getState();const empty=Object.values(s.tabs).find(t=>t.windowId===${JSON.stringify(window)}&&!t.url);if(empty){s.navigate(empty.id,${JSON.stringify(url)});s.activate(empty.id);return empty.id;}return s.newTab(${JSON.stringify(window)},{url:${JSON.stringify(url)}});`);
    await this.loaded(id, path.startsWith("http") ? undefined : titleOf(path));
    if(this.options.foreground) await this.until(`return ac.engine.call("webKit.devPageState",{tabId:${JSON.stringify(id)}}).then(s=>s.active&&s.key);`,10000);
    return id;
  }
  async loaded(id, title) {
    await this.until(`const t=ac.store.getState().tabs[${JSON.stringify(id)}];return t&&ac.webviews.has(t.id)${title ? `&&t.title===${JSON.stringify(title)}` : "&&t.title"};`, 30000);
    await this.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(document.readyState));').then(s=>s==="complete");`, 30000);
  }
  async activate(id) {
    await this.evaluate(`ac.store.getState().activate(${JSON.stringify(id)});return true;`);
    await this.until(`return ac.webviews.has(${JSON.stringify(id)});`);
  }
  page(id, expression) { return this.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).evaluate(${JSON.stringify(`post("result",JSON.stringify(${expression}));`)});`); }
  execute(id, code) { return this.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).executeJavaScript(${JSON.stringify(code)});`); }
  async type(text) {
    if (!this.driver || !await this.evaluate(`return !!ac.omnibox.get(${JSON.stringify(this.driver)});`)) {
      await this.evaluate(`ac.runCommand({command:"focusCommandBar",arg:null,windowId:${JSON.stringify(this.window)}});return true;`);
      this.driver = await this.until(`return ac.omnibox.ids().find(id=>id.startsWith(${JSON.stringify(this.window + ":")}));`);
    }
    await this.evaluate(`ac.omnibox.get(${JSON.stringify(this.driver)}).type(${JSON.stringify(text)});return true;`);
    await this.until(`return ac.omnibox.get(${JSON.stringify(this.driver)})?.state().typed===${JSON.stringify(text)};`);
  }
  suggestions() { return this.evaluate(`return ac.omnibox.get(${JSON.stringify(this.driver)}).state().items;`); }
  async submit() { await this.evaluate(`ac.omnibox.get(${JSON.stringify(this.driver)}).submit();return true;`); }
  history() { return this.evaluate('return ac.engine.call("history.query",{profile:"",maxUrls:5000,maxVisits:50});'); }
  async sql(query) {
    assert.ok(existsSync(this.store), "profile store does not exist");
    return (await run("sqlite3", [this.store, query])).text.trim();
  }
  async snapshot(name = "window.png", windowNumber = null) {
    const path = join(this.data, name);
    const result = await this.evaluate(`return ac.engine.call("windows.list").then(w=>ac.engine.call("windows.dev",{window:${windowNumber ?? "w.find(w=>w.hasRoot).window"},action:${JSON.stringify("snapshotFrame:" + path)}}));`);
    assert.equal(result, "ok");
    const png = readFileSync(path);
    assert.equal(png.subarray(0, 8).toString("hex"), "89504e470d0a1a0a");
    return { width: png.readUInt32BE(16), height: png.readUInt32BE(20), bytes: png.length };
  }
}
