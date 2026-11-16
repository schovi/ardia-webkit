document.documentElement.dataset.extensionContent = "changed";
const handler = window.webkit?.messageHandlers?.ardiaPasswords;
let reachedPasswordHandler = false;
try {
  handler.postMessage({ kind: "request", token: "fixture", data: {} });
  reachedPasswordHandler = true;
} catch {}
document.documentElement.dataset.extensionPasswordAccess = JSON.stringify({ handler: reachedPasswordHandler, api: typeof window.__ardiaPasswords !== "undefined" });
browser.runtime.sendMessage("gate").then(reply => document.documentElement.dataset.extensionWorker = reply);
