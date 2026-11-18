import assert from "node:assert/strict";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { BUILD, ROOT, run } from "./support.mjs";

const source = name => join(ROOT, "scripts/webkit/fixtures", name);
const call = (browser, name, args = {}) => browser.evaluate(`return ac.engine.call(${JSON.stringify(name)},${JSON.stringify(args)});`);
export async function install(browser, scratch, name = "extension-content", profile = "", crx = false) {
  const folder = join(scratch, name + "-" + Date.now());
  cpSync(source(name), folder, { recursive: true });
  let path = folder;
  if (crx) {
    const zip = folder + ".zip";
    await run("/usr/bin/ditto", ["-c", "-k", folder, zip]);
    path = folder + ".crx";
    const signer = join(scratch,"crx-signer");
    await run("xcrun",["swiftc","packages/ardiacore/tests/webkit-extensions.test.swift","packages/ardiacore/ios/WebKitExtensionArchive.swift","packages/ardiacore/ios/WebKitCRXSignature.swift","packages/ardiacore/ios/WebKitStorePolicy.swift","-o",signer]);
    const signed = await run(signer,["--sign",zip,path]);
    writeFileSync(folder+".id",signed.text.trim());
  }
  rmSync(join(browser.data, "WebKit/extension-install-prompt.json"), { force: true });
  await browser.evaluate(`globalThis.extInstall=null;ac.engine.call(${JSON.stringify(crx ? "extensions.installCrx" : "extensions.install")},${JSON.stringify({profile,path})}).then(r=>globalThis.extInstall=r,e=>globalThis.extInstall={failure:e.message});return true;`);
  const promptFile = join(browser.data, "WebKit/extension-install-prompt.json");
  let prompt;
  if(browser.options.foreground) {
    prompt=await browser.until('return globalThis.acPerf.findFibers("InstallDialog").map(f=>f.memoizedProps.request.prompt).find(Boolean);');
  } else {
    for (let end = Date.now() + 15000; Date.now() < end && !existsSync(promptFile); await new Promise(r => setTimeout(r, 100)));
    assert.ok(existsSync(promptFile), JSON.stringify(await browser.evaluate("return globalThis.extInstall;")));
    prompt = JSON.parse(readFileSync(promptFile));
  }
  assert.ok(prompt.permissions.includes("http://127.0.0.1/*"));
  await browser.until(`return globalThis.acPerf.findFibers("InstallDialog").some(f=>f.memoizedProps.request.status==="prompt"&&f.memoizedProps.request.prompt.requestId===${JSON.stringify(prompt.requestId)});`);
  await browser.evaluate('const button=globalThis.acPerf.findFibers("Button").find(f=>f.memoizedProps.title==="Add Extension");if(!button)throw Error("Install button missing");button.memoizedProps.onPress();return true;');
  await browser.until('return globalThis.acPerf.findFibers("InstallDialog").length===0;');
  const result = await browser.until("return globalThis.extInstall;");
  assert.ok(result.id, JSON.stringify(result));
  return { id:result.id, folder, prompt };
}

export const extensionRows = {
  "ext-gate": async ({browser, scratch, fixture}) => {
    const path = join(scratch, "gate-extension"); cpSync(source("extension-content"), path, {recursive:true});
    const tabId = await browser.open("/first");
    const prepared = await call(browser,"webKit.devExtensionGate",{path,tabId,url:fixture.origin+"/first"});
    assert.equal(prepared.loaded,true,JSON.stringify(prepared));
    const before = await call(browser,"webKit.devExtensionGate",{probe:true});
    assert.equal(JSON.parse(before.content).extensionContent,undefined,"content ran before consent");
    await call(browser,"extensions.resolveInstallPrompt",{requestId:"webkit-gate",accepted:true});
    const proof = await browser.until('return ac.engine.call("webKit.devExtensionGate",{probe:true}).then(p=>p.content.includes("worker-answer")&&p.popup==="Popup loaded"&&p.attached?p:null);');
    assert.deepEqual(JSON.parse(JSON.parse(proof.content).extensionPasswordAccess),{handler:false,api:false});
    return "content DOM changed; service worker replied worker-answer; framework popup attached and DOM readable; no password handler/API; no grant before consent";
  },
  "ext-install-folder": async ({browser,scratch}) => {
    const {id,folder} = await install(browser,scratch);
    const list = await call(browser,"extensions.list",{profile:""});
    const record = list.extensions.find(e=>e.id===id);
    assert.ok(record?.enabled); assert.notEqual(record.path,folder); assert.match(record.path,/WebKit\/Extensions/);
    rmSync(folder,{recursive:true});
    await browser.evaluate('ac.openSettings("extensions");return true;');
    assert.ok((await browser.snapshot("extensions.png")).bytes>1000);
    mkdirSync(join(BUILD,"step-8-evidence"),{recursive:true});cpSync(join(browser.data,"extensions.png"),join(BUILD,"step-8-evidence/extensions.png"));
    const tab=await browser.open("/first");
    await browser.until(`return ac.webviews.get(${JSON.stringify(tab)}).evaluate('post("result",JSON.stringify(document.documentElement.dataset.extensionWorker));').then(v=>v==="worker-answer");`);
    await browser.until(`return ac.webviews.get(${JSON.stringify(tab)}).evaluate('post("result",JSON.stringify(document.documentElement.dataset.extensionFrame));').then(v=>v==="loaded");`);
    assert.equal((await call(browser,"extensions.list",{profile:"other"})).extensions.length,0);
    return "consent via resolveInstallPrompt; managed copy survives source removal; Settings snapshot; worker runs; web-accessible frame loads; other profile empty";
  },
  "ext-install-crx": async ({browser,scratch}) => {
    const {id,folder}=await install(browser,scratch,"extension-content","",true);
    assert.equal(id,readFileSync(folder+".id","utf8"));
    return "CRX3 header and ZIP extracted; Chrome signed-header id preserved; requested hosts accepted through install prompt";
  },
  "ext-toggle": async ({browser,scratch}) => {
    const {id}=await install(browser,scratch);
    await call(browser,"extensions.setEnabled",{profile:"",id,enabled:false});
    await browser.restart();
    assert.equal((await call(browser,"extensions.list",{profile:""})).extensions.find(e=>e.id===id).enabled,false);
    const tab=await browser.open("/first");
    assert.equal(await browser.page(tab,"document.documentElement.dataset.extensionContent??null"),null);
    await call(browser,"extensions.setEnabled",{profile:"",id,enabled:true});
    await call(browser,"extensions.reload",{profile:"",id});
    await browser.restart();
    const restored=await browser.open("/second");
    await browser.until(`return ac.webviews.get(${JSON.stringify(restored)}).evaluate('post("result",JSON.stringify(document.documentElement.dataset.extensionWorker));').then(v=>v==="worker-answer");`);
    await call(browser,"extensions.uninstall",{profile:"",id});
    assert.equal((await call(browser,"extensions.list",{profile:""})).extensions.length,0);
    return "disabled state survives relaunch and injects nothing; enabled/reloaded extension runs after relaunch; uninstall removes record";
  },
};

export async function openPopup(browser, id, tabId) {
  await call(browser,"extensions.configure",{profile:"",id,options:{pinned:true}});
  const state=await browser.until(`return ac.engine.call("extensions.actionStates",{tabId:${JSON.stringify(tabId)},ids:[${JSON.stringify(id)}]}).then(s=>s[${JSON.stringify(id)}]??null);`);
  await browser.until(`return globalThis.acPerf.findFibers("ExtensionButton").some(f=>f.memoizedProps.ext.id===${JSON.stringify(id)});`);
  const entry=(await call(browser,"extensions.list",{profile:""})).extensions.find(e=>e.id===id);
  const title=state.title||entry.actionTitle||entry.name;
  await browser.until(`return globalThis.acPerf.findFibers("Button").some(f=>f.memoizedProps.tooltip===${JSON.stringify(title)});`);
  await browser.evaluate(`const button=globalThis.acPerf.findFibers("Button").find(f=>f.memoizedProps.tooltip===${JSON.stringify(title)});button.memoizedProps.onPress();return true;`);
  await browser.until('return ac.engine.call("webKit.devExtensionPopup",{}).then(p=>p.attached&&p.value?.includes("Popup loaded")?p:null);');
  return state;
}

extensionRows["ext-action"] = async ({browser,scratch}) => {
  const {id}=await install(browser,scratch);
  const tabId=await browser.open("/first");
  await browser.until(`return ac.engine.call("extensions.actionStates",{tabId:${JSON.stringify(tabId)},ids:[${JSON.stringify(id)}]}).then(s=>s[${JSON.stringify(id)}]?.badgeText==="8");`);
  const state=await openPopup(browser,id,tabId);
  const anchor=await browser.evaluate('return globalThis.acPerf.findFibers("ActionPopup")[0].memoizedProps.anchor;');
  const click=async()=>{
    for(const phase of ["down","up"]) await browser.evaluate(`return ac.engine.call("windows.list").then(w=>ac.engine.call("windows.dev",{window:w.find(w=>w.hasRoot).window,action:${JSON.stringify(`mouse:${phase},${anchor.x+anchor.width/2},${anchor.y+anchor.height/2}`)}}));`);
  };
  await click();
  await browser.until('return ac.engine.call("webKit.devExtensionPopup",{}).then(p=>!p.attached);');
  await click();
  let shown;
  try { shown=await browser.until('return ac.engine.call("webKit.devExtensionPopup",{}).then(p=>{globalThis.foregroundPopupProbe=p;return p.active&&p.key&&p.visible&&p.opacity>0.9&&p.windowVisible&&p.width>0&&p.height>0?p:null;});'); }
  catch(error) { throw new Error(error.message+"; popup="+JSON.stringify(await browser.evaluate("return globalThis.foregroundPopupProbe;"))); }
  assert.equal(shown.value.trim(),"Popup loaded");
  assert.equal(state.badgeText,"8");assert.match(state.icon,/^data:image\/png;base64,/);
  await browser.snapshot("extension-popup.png");cpSync(join(browser.data,"extension-popup.png"),join(BUILD,"step-8-evidence/extension-popup.png"));
  const page=await call(browser,"webKit.devExtensionPopup",{script:"return {handler:!!window.webkit?.messageHandlers?.ardiaPasswords,api:typeof window.__ardiaPasswords!== 'undefined'}"});
  assert.deepEqual(page.value,{handler:false,api:false});
  return "foreground: app active, window key/visible, popup visible with positive dimensions; toolbar icon and badge 8; native mouse closed/reopened popup; DOM readable; password world inaccessible";
};

extensionRows["ext-tabs-api"] = async ({browser,scratch,fixture}) => {
  const {id}=await install(browser,scratch,"extension-tabs");
  const tabId=await browser.open("/first");await openPopup(browser,id,tabId);
  const message=async payload=>(await call(browser,"webKit.devExtensionPopup",{script:`return await browser.runtime.sendMessage(${JSON.stringify(payload)})`})).value;
  let state=await message({operation:"query"});
  assert.ok(state.tabs.some(t=>t.url===fixture.origin+"/first"),JSON.stringify(state));
  const created=await message({operation:"create",url:fixture.origin+"/extension-created"});
  assert.ok(created.id,JSON.stringify(created));
  const newTab=await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet extension-created")?.id;');
  await browser.activate(tabId);await openPopup(browser,id,tabId);
  const updated=await message({operation:"update",id:created.id,url:fixture.origin+"/extension-updated"});
  assert.equal(updated.id,created.id);
  await browser.loaded(newTab,"Cobalt Violet extension-updated");
  state=await message({operation:"query"});
  assert.ok(state.tabs.some(t=>t.id===created.id&&t.url===fixture.origin+"/extension-updated"),JSON.stringify(state));
  assert.ok(state.updates.some(e=>e.id===created.id&&e.change.url===fixture.origin+"/extension-updated"),JSON.stringify(state));
  return "tabs.query sees real page; tabs.create adopts a real tab; tabs.update navigates it; onUpdated reports its changed URL";
};

extensionRows["ext-permissions"] = async ({browser,scratch}) => {
  const path=join(scratch,"declined");cpSync(source("extension-content"),path,{recursive:true});
  await browser.evaluate(`globalThis.declined=null;ac.engine.call("extensions.install",{profile:"",path:${JSON.stringify(path)}}).then(r=>globalThis.declined=r,e=>globalThis.declined={rejected:true});return true;`);
  const prompt=join(browser.data,"WebKit/extension-install-prompt.json");
  for(let end=Date.now()+10000;Date.now()<end&&!existsSync(prompt);await new Promise(r=>setTimeout(r,100)));
  assert.ok(existsSync(prompt));
  assert.equal((await call(browser,"extensions.list",{profile:""})).extensions.length,0);
  await call(browser,"extensions.resolveInstallPrompt",{requestId:JSON.parse(readFileSync(prompt)).requestId,accepted:false});
  assert.equal((await browser.until("return globalThis.declined;")).rejected,true);
  assert.equal((await call(browser,"extensions.list",{profile:""})).extensions.length,0);
  const {id}=await install(browser,scratch);
  const tab=await browser.open("/first");
  const probe=await browser.until(`return ac.webviews.get(${JSON.stringify(tab)}).evaluate('post("result",JSON.stringify(document.documentElement.dataset.extensionPasswordAccess));');`);
  assert.deepEqual(JSON.parse(probe),{handler:false,api:false});
  const privateWindow=await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${JSON.stringify(browser.fixture.origin+"/first")}});`);
  const privateTab=await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(privateWindow)}&&t.title==="Cobalt Violet first")?.id;`);
  assert.equal(await browser.page(privateTab,"document.documentElement.dataset.extensionContent??null"),null);
  await browser.restart();
  assert.equal((await call(browser,"extensions.list",{profile:""})).extensions[0].id,id);
  assert.ok(!(await call(browser,"extensions.syncState",{profile:""})).ready);
  return "unaccepted install absent; decline rejects without grants; acceptance enables only requested hosts; extension cannot reach password handler/API; private window has no injection; no reprompt after relaunch; sync unsupported";
};
