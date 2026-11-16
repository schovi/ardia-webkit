import assert from "node:assert/strict";
import { test } from "node:test";
import { useBrowser } from "../browser/store.ts";
import { applyResult } from "./apply.ts";

test("failed password writes never count as imported", async () => {
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

test("passwords enter the unlock selection while autofill stays unsupported", async () => {
  const {setImportKinds,importNow,toggleImportKind} = await import("./flow.ts");
  setImportKinds(["bookmarks","passwords","autofill"]);
  toggleImportKind("passwords",true);
  toggleImportKind("autofill",true);
  assert.deepEqual([...importNow().kinds],["bookmarks","passwords"]);
});

test("successful password imports count native writes and clear input secrets", async () => {
  const stub = await import("../../test-native/index.ts");
  stub.passwordStores.set(stub.current.device, new Map());
  useBrowser.getState().hydrate({});
  useBrowser.getState().createWindow({});
  const credentials = [{url:"https://fixture.example/login",username:"fixture",password:"fixture-secret"}];
  const failures = [];
  const counts = await applyResult("default", {favorites:[],tabs:[],spaces:[],history:[],credentials}, "Fixture", ["passwords"], kind=>failures.push(kind));
  assert.equal(counts.passwords, 1);
  assert.deepEqual(failures, []);
  assert.equal(credentials[0].password, "");
});
