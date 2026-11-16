import { localImportRows } from "./import-rows.mjs";
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Browser, ROOT, run } from "./support.mjs";
import { startFixture } from "./fixture.mjs";
import { foregroundRows } from "./window-rows.mjs";
import { ALLOWED_TEST, browserRows, rows } from "./rows.mjs";
import { parseOptions, standinReport, resultFails } from "./report.mjs";

const names = Object.keys(rows);
const help = `Usage: scripts/webkit/check [--no-build] [--only <row>]
Default: rebuild Release and its zip, then run every row.
--no-build: reuse the last Release build.
--only <row>: run one independent row.
Local-only rows: ${[...localImportRows].join(", ")} (SKIPPED (no source profile) when absent).
Rows: ${names.join(", ")}
Offline network rows are skipped (offline) and return a nonzero exit.
Only allowed JS failure: ${ALLOWED_TEST}
`;
const cell = (text) => String(text).replace(/\|/g, "\\|").replace(/\s*\n\s*/g, "; ");
function table(results) {
  console.log("| Row | Result | Evidence |");
  console.log("|---|---|---|");
  for (const result of results) console.log(`| ${result.row} | ${result.status} | ${cell(result.evidence)} |`);
}

async function check(options) {
  if (options.build) {
    console.error("check: build");
    try {
      const built = await run(process.execPath, ["scripts/webkit/build.mjs"], { timeout: 1200000 });
      console.error(built.text.trim());
    } catch (error) { table([{ row: "build", status: "FAIL", evidence: error.message }]); process.exitCode = 1; return; }
  }
  const scratch = mkdtempSync(join(tmpdir(), "ardia-webkit-check-"));
  const launches = [], results = [];
  let fixture, current;
  let interrupted = false;
  const interrupt = async () => {
    if (interrupted) return;
    interrupted = true;
    try { await current?.stop(); } catch (error) { console.error(error.message); }
    await fixture?.close();
    rmSync(scratch, { recursive: true, force: true });
    process.exit(130);
  };
  process.once("SIGINT", interrupt); process.once("SIGTERM", interrupt);
  try {
    fixture = await startFixture();
    for (const name of options.rows) {
      console.error(`check: ${name}`);
      let result;
      current = null;
      try {
        if (browserRows.has(name)) current = new Browser(join(scratch, name), fixture, launches, name === "no-upstream" ? { onboarding: true, observe: true } : {foreground:foregroundRows.has(name)});
        if (current) await current.launch();
        const evidence = await rows[name]({ browser: current, fixture, scratch, launches });
        result = { row: name, status: "PASS", evidence };
      } catch (error) {
        try { current?.assertNoModalAlert(); } catch (alert) { error = alert; }
        result = { row: name, status: error.resultStatus ?? (error.offline ? "skipped (offline)" : "FAIL"), evidence: error.message };
      } finally {
        try { await current?.stop(); }
        catch (error) { result = { row: name, status: "FAIL", evidence: `${result?.evidence ?? ""}; cleanup: ${error.message}` }; }
      }
      results.push(result);
    }
    const sourceDirectory = join(ROOT, "packages/ardiacore/ios/webkit");
    const sources = readdirSync(sourceDirectory).filter((name) => name.endsWith(".mm")).map((name) => readFileSync(join(sourceDirectory, name), "utf8"));
    const logs = launches.map((app) => existsSync(app.log) ? readFileSync(app.log, "utf8") : "");
    const report = standinReport(sources, logs, options.rows);
    writeFileSync(join(ROOT, "docs/webkit/standins.md"), report);
    if (results.some((result) => resultFails(result.status))) process.exitCode = 1;
  } finally {
    await fixture?.close();
    rmSync(scratch, { recursive: true, force: true });
    process.removeListener("SIGINT", interrupt); process.removeListener("SIGTERM", interrupt);
    console.error(`scratch removed: ${scratch}`);
  }
  table(results);
  if (results.some(r=>r.status==="NEEDS PERSON"||r.status.toUpperCase().startsWith("SKIPPED"))) console.log(`Manual checklist: ${join(ROOT,"docs/webkit/needs-person.md")}`);
}

try {
  if (process.argv.includes("--help")) console.log(help);
  else await check(parseOptions(process.argv.slice(2), names));
} catch (error) {
  console.error(error.stack ?? error.message);
  process.exitCode = 1;
}
