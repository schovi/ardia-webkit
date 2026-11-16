import assert from "node:assert/strict";
import { test } from "node:test";
import { useBrowser } from "../browser/store.ts";
import { applyResult } from "./apply.ts";

test("unsupported passwords never count as imported", async () => {
  useBrowser.getState().hydrate({});
  useBrowser.getState().createWindow({});
  const failures = [];
  const counts = await applyResult("default", {
    favorites: [], tabs: [], spaces: [], history: [],
    credentials: [{url:"https://fixture.example/",username:"fixture",password:"fixture"}],
  }, "Fixture", ["passwords"], kind => failures.push(kind));
  assert.equal(counts.passwords, 0);
  assert.deepEqual(failures, ["passwords"]);
});

test("unsupported kinds cannot enter the unlock selection", async () => {
  const {setImportKinds,importNow,toggleImportKind} = await import("./flow.ts");
  setImportKinds(["bookmarks","passwords","autofill"]);
  toggleImportKind("passwords",true);
  toggleImportKind("autofill",true);
  assert.deepEqual([...importNow().kinds],["bookmarks"]);
});
