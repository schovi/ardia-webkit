import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import { test } from "node:test";

globalThis.__DEV__ = false;
const toasts = new Map();
globalThis.engineTestToasts = toasts;
const stubs = {
  "../app/toasts": `export const showToast = (windowId, title, message, options) => globalThis.engineTestToasts.set(windowId, { title, ...options });
    export const hideKeyedToast = (windowId, key) => globalThis.engineTestToasts.get(windowId)?.key === key && globalThis.engineTestToasts.delete(windowId);`,
  "../tabs/tabPages": "export const wantsPage = (t) => !!t && !!(t.page.nav || t.page.adopt);",
};
registerHooks({
  resolve(specifier, context, next) {
    if (!context.parentURL?.endsWith("/state/engines/actions.ts") || !(specifier in stubs)) return next(specifier, context);
    return { url: `data:text/javascript,${encodeURIComponent(stubs[specifier])}`, shortCircuit: true };
  },
});

const { useBrowser } = await import("../browser/store.ts");
const model = await import("../browser/model.ts");
const { offerWebKit } = await import("./actions.ts");

const S = () => useBrowser.getState();
test("WebKit pages do not offer an engine move or create a move-back toast", () => {
  S().hydrate({});
  const w = S().createWindow({ url: "https://www.netflix.com/watch/1" });
  const tabId = model.activeTabId(S(), w);
  offerWebKit(tabId, { keySystem: "com.widevine.alpha", main: true });
  assert.equal(toasts.has(w), false);
  assert.deepEqual(S().settings.websiteEngines, {});
});
