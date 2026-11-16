import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { APP, BUILD, ZIP, run } from "./support.mjs";

if (process.argv.includes("--help")) {
  console.log("Usage: scripts/webkit/build\nBuild bundled Release JS with Node 24 and ad hoc signing, then zip the app.");
} else {
  try {
    if (process.argv.length > 2) throw new Error("Usage: scripts/webkit/build");
    mkdirSync(BUILD, { recursive: true });
    const log = join(BUILD, "build-webkit.log");
    console.error(`Release build: ${log}`);
    const result = await run("scripts/agent/locked", ["xcodebuild", "--wait", "500", "--", "xcodebuild",
      "-workspace", "apps/browser/macos/Ardia.xcworkspace", "-scheme", "Ardia-macOS", "-derivedDataPath", "apps/browser/build-webkit",
      "-destination", "platform=macOS,arch=arm64", "-configuration", "Release", "-xcconfig", "apps/browser/macos/AdHoc.xcconfig", "-hideShellScriptEnvironment",
      `SYMROOT=${join(BUILD, "Build/Products")}`, `OBJROOT=${join(BUILD, "Build/Intermediates.noindex")}`, "build"],
    { log, timeout: 1200000, env: { NODE_BINARY: process.execPath } });
    if (!result.text.includes("** BUILD SUCCEEDED **")) throw new Error("xcodebuild did not report success");
    console.log("** BUILD SUCCEEDED **");
    await run("ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", APP, ZIP]);
    console.log(`app: ${APP}`);
    console.log((await run("shasum", ["-a", "256", ZIP])).text.trim());
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
