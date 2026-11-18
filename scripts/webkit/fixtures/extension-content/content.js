document.documentElement.dataset.extensionContent = "changed";
const handler = window.webkit?.messageHandlers?.ardiaPasswords;
let reachedPasswordHandler = false;
try {
  handler.postMessage({ kind: "request", token: "fixture", data: {} });
  reachedPasswordHandler = true;
} catch {}
document.documentElement.dataset.extensionPasswordAccess = JSON.stringify({ handler: reachedPasswordHandler, api: typeof window.__ardiaPasswords !== "undefined" });
browser.runtime.sendMessage("gate").then(reply => document.documentElement.dataset.extensionWorker = reply);
addEventListener("message", event => {
  if (event.data?.ardiaExtensionFrame) document.documentElement.dataset.extensionFrame = event.data.ardiaExtensionFrame;
});
const frame = document.createElement("iframe");
frame.src = browser.runtime.getURL("frame.html");
frame.style.display = "none";
document.documentElement.append(frame);
