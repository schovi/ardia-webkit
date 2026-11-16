import assert from "node:assert/strict";
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { BUILD, sleep } from "./support.mjs";

export function assertNoJavaScriptException(log) {
  const lines = log.split("\n").filter(line => /\b[A-Za-z]*Error:|Unhandled JS Exception|^\S+ error /.test(line));
  assert.deepEqual(lines, [], `JS exception: ${lines.join("; ")}`);
}

export async function settingsTour({ browser }) {
  const evidence = join(BUILD, "settings-tour-evidence");
  mkdirSync(evidence, { recursive: true });
  const results = [];
  const panes = await browser.evaluate('return ac.settingsPanes.map(p=>p.id);');
  assert.ok(panes.length > 0, "no Settings panes found");
  let offset = 0;
  let settingsWindow = null;
  for (const pane of panes) {
    console.error(`settings-tour: ${pane}`);
    const started = Date.now();
    try {
      const before = await browser.evaluate('return ac.engine.call("windows.list").then(w=>w.map(w=>w.window));');
      await browser.evaluate(`ac.store.getState().updateSettings({showAdvancedSettings:true});ac.openSettings(${JSON.stringify(pane)});return true;`);
      if (!settingsWindow) settingsWindow = await browser.until(`return ac.engine.call("windows.list").then(w=>w.find(w=>w.hasRoot&&!${JSON.stringify(before)}.includes(w.window))?.window);`);
      await browser.until(`return ac.settingsNav.getState().pane===${JSON.stringify(pane)};`);
      await sleep(1200);
      const path = join(browser.data, `pane-${pane}.png`);
      const action = `snapshotPane:settings-pane-${pane}|${path}`;
      const result = await browser.evaluate(`return ac.engine.call("windows.dev",{window:${settingsWindow},action:${JSON.stringify(action)}});`);
      assert.equal(result, "ok", `${pane}: ${result}`);
      assert.ok(readFileSync(path).length > 1000, "pane snapshot is empty");
      copyFileSync(path, join(evidence, `${pane}.png`));
      const logPath = join(browser.data, "dev-console.log");
      const log = existsSync(logPath) ? readFileSync(logPath, "utf8") : "";
      assertNoJavaScriptException(log.slice(offset));
      assert.ok(browser.app.alive, "app died after rendering the pane");
      results.push({ pane, result: "PASS", milliseconds: Date.now() - started });
    } catch (error) {
      results.push({ pane, result: "FAIL", error: error.message });
    } finally {
      const logPath = join(browser.data, "dev-console.log");
      if (existsSync(logPath)) {
        const log = readFileSync(logPath, "utf8");
        writeFileSync(join(evidence, `${pane}.log`), log.slice(offset));
        offset = log.length;
      }
      if (!browser.app.alive) { await browser.restart(); offset = 0; settingsWindow = null; }
    }
  }
  writeFileSync(join(evidence, "results.json"), JSON.stringify(results, null, 2) + "\n");
  assert.deepEqual(results.filter(r => r.result !== "PASS"), [], "Settings panes failed");
  return `${panes.length} panes: ${panes.join(", ")}; roots rendered; nonblank snapshots; no JS exceptions; ${evidence}`;
}
