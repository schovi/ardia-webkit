import assert from "node:assert/strict";
import { existsSync, mkdirSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { AD_PATH, titleOf } from "./fixture.mjs";

const call = (browser, name, args = {}) => browser.evaluate(`return ac.engine.call(${JSON.stringify(name)},${JSON.stringify(args)});`);
const web = (browser, id, method, args = []) => browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).${method}(${args.map(JSON.stringify).join(",")});`);
const settings = (browser, origin, profile = "", engine = "webkit") => call(browser,"sites.settings",{profile,origin,engine});
const set = (browser, origin, type, value, profile = "", engine = "webkit") => call(browser,"sites.setSetting",{profile,origin,type,value,engine});

export const settingsRows = {
  "zoom-site": async ({browser,fixture}) => {
    const id = await browser.open("/zoom");
    await web(browser,id,"zoomStep",[1]);
    await browser.until(`return ac.engine.call("sites.zoomLevels",{profile:""}).then(s=>s["127.0.0.1"]===1.1);`);
    await call(browser,"sites.setZoom",{profile:"work",host:"127.0.0.1",zoom:1.5});
    await browser.restart();
    await browser.activate(id); await browser.loaded(id);
    await browser.until(`return ac.store.getState().tabs[${JSON.stringify(id)}].zoom===1.1;`);
    assert.equal((await call(browser,"sites.zoomLevels",{profile:"work"}))["127.0.0.1"],1.5);
    await call(browser,"sites.setZoom",{profile:"",host:"127.0.0.1",zoom:1});
    await browser.until(`return ac.store.getState().tabs[${JSON.stringify(id)}].zoom===1;`);
    assert.equal((await call(browser,"sites.zoomLevels",{profile:""}))["127.0.0.1"],undefined);
    return "zoom step persisted in SQLite; relaunch applied 1.1; other profile retained 1.5; Settings reset updated live page";
  },
  "site-settings": async ({browser,fixture}) => {
    const id = await browser.open("/permissions");
    for (const value of ["allow","block"]) {
      for (const kind of ["camera","microphone","location","popups","sound"]) await set(browser,fixture.origin,kind,value);
      await browser.restart(); await browser.activate(id); await browser.loaded(id);
      for (const kind of ["camera","microphone","location","popups","sound"]) {
        assert.equal((await settings(browser,fixture.origin))[kind].value,value);
        assert.equal((await settings(browser,fixture.origin,"","chromium"))[kind].value,value);
        assert.equal((await settings(browser,fixture.origin,"work"))[kind].isDefault,true);
      }
      await browser.execute(id,'document.body.append(document.createElement("audio"))');
      await set(browser,fixture.origin,"sound",value);
      await browser.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(document.querySelector("audio").muted===${value==="block"}));');`);
      for (const kind of ["camera","microphone"]) assert.equal(await call(browser,"webKit.devPermission",{tabId:id,kind}),value==="allow");
      assert.ok((await call(browser,"sites.origins",{profile:""})).includes(fixture.origin));
    }
    assert.ok(Number(await browser.sql("SELECT COUNT(*) FROM settings WHERE section='sites';"))>0);
    await call(browser,"sites.reset",{profile:"",origin:fixture.origin});
    assert.deepEqual(await call(browser,"sites.origins",{profile:""}),[]);
    assert.equal((await settings(browser,fixture.origin)).popups.isDefault,true);
    const accepted = await browser.evaluate(`const subscription=ac.engine.on("permissions.requested",e=>{if(e.origin===${JSON.stringify(fixture.origin)})void ac.engine.call("permissions.resolve",{id:e.id,result:"accept",remember:true});});return ac.engine.call("webKit.devPermission",{tabId:${JSON.stringify(id)},kind:"camera"}).finally(()=>subscription.remove());`);
    assert.equal(accepted,true);
    await browser.restart();
    assert.equal((await settings(browser,fixture.origin)).camera.value,"allow");
    return "all five allow/block decisions survived two relaunches; profile isolation; Settings origins and reset; real media delegate grant/deny without capture; location storage only (system consent avoided)";
  },
  "clear-site-data": async ({browser,fixture}) => {
    const first = await browser.open("/clear");
    const otherOrigin = fixture.origin.replace("127.0.0.1","localhost");
    const other = await browser.open(otherOrigin+"/keep");
    for (const id of [first,other]) await browser.page(id,'(document.cookie="site=kept;path=/",localStorage.setItem("site","kept"),true)');
    await call(browser,"sites.clearData",{profile:"",origin:fixture.origin,engine:"chromium"});
    await web(browser,first,"reload"); await browser.loaded(first,titleOf("/clear"));
    await browser.until(`return ac.webviews.get(${JSON.stringify(first)}).evaluate('post("result",JSON.stringify(!document.cookie.includes("site=")&&localStorage.getItem("site")===null));');`);
    assert.equal(await browser.page(other,'document.cookie.includes("site=kept")&&localStorage.getItem("site")==="kept"'),true);
    return "127.0.0.1 cookies and localStorage cleared after reload; localhost cookies and localStorage retained";
  },
  "blocker-controls": async ({browser,fixture}) => {
    await browser.open("/blocker");
    await browser.until('return ac.engine.call("webKit.devContentBlocker").then(s=>s.ready&&s.lists>0);',60000);
    const load = async expected => {
      const id = await browser.open("/blocker-"+Date.now());
      const result = await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).evaluate(${JSON.stringify(`const s=document.createElement("script");s.src=${JSON.stringify(fixture.origin+AD_PATH)};s.onload=()=>post("result",JSON.stringify("loaded"));s.onerror=()=>post("result",JSON.stringify("blocked"));document.head.append(s);`)});`);
      assert.equal(result,expected);
      return id;
    };
    await load("blocked");
    assert.ok((await call(browser,"contentBlocker.state")).stats.blocked>0);
    await call(browser,"contentBlocker.setEnabled",{enabled:false}); await load("loaded");
    await call(browser,"contentBlocker.setEnabled",{enabled:true}); await load("blocked");
    await call(browser,"contentBlocker.setListEnabled",{id:"easylist",enabled:false});
    await browser.until('return ac.engine.call("webKit.devContentBlocker").then(s=>s.loading===null);',60000);
    await load("loaded");
    await call(browser,"contentBlocker.setListEnabled",{id:"easylist",enabled:true});
    await browser.until('return ac.engine.call("webKit.devContentBlocker").then(s=>s.loading===null);',60000);
    await load("blocked");
    await call(browser,"contentBlocker.setAllowed",{host:"127.0.0.1",allowed:true});
    assert.equal(await call(browser,"contentBlocker.isAllowed",{host:"127.0.0.1"}),true);
    await load("loaded"); await browser.restart();
    assert.equal(await call(browser,"contentBlocker.isAllowed",{host:"127.0.0.1"}),true);
    await call(browser,"contentBlocker.setAllowed",{host:"127.0.0.1",allowed:false}); await load("blocked");
    return "global and EasyList toggles changed actual ad loads; per-host exemption survived relaunch; reset blocked again; Settings count > 0";
  },
  "download-settings": async ({browser,fixture}) => {
    const folder = join(browser.data,"chosen-downloads"); mkdirSync(folder);
    await call(browser,"downloads.setSettings",{profile:"",folder,askWhereToSave:true}); await browser.restart();
    assert.deepEqual(await call(browser,"downloads.settings",{profile:""}),{folder,askWhereToSave:true});
    const id = await browser.open("/downloads");
    await browser.evaluate('globalThis.settingsDownloads=[];ac.engine.on("downloads.changed",e=>globalThis.settingsDownloads.push(e));return true;');
    await web(browser,id,"loadUrl",[fixture.origin+"/download",true]);
    const small = await browser.until('return globalThis.settingsDownloads.find(d=>d.state==="finished");');
    assert.equal(small.path,join(folder,"smoke.txt"));
    assert.match(readFileSync(browser.app.log,"utf8"),/save panel \(background mode, not shown\)/);
    await web(browser,id,"loadUrl",[fixture.origin+"/slow-download",true]);
    const item = await browser.until('return globalThis.settingsDownloads.find(d=>d.filename==="slow.bin"&&d.received>0);');
    await call(browser,"downloads.pause",{id:item.id});
    await browser.until(`return globalThis.settingsDownloads.filter(d=>d.id===${JSON.stringify(item.id)}&&d.paused).length>=2;`);
    await call(browser,"downloads.resume",{id:item.id});
    const finished = await browser.until(`return globalThis.settingsDownloads.find(d=>d.id===${JSON.stringify(item.id)}&&d.state==="finished");`,30000);
    assert.equal(readFileSync(finished.path).length,8*1024*1024);
    await web(browser,id,"loadUrl",[fixture.origin+"/slow-download",true]);
    const cancel = await browser.until(`return globalThis.settingsDownloads.find(d=>d.filename==="slow.bin"&&d.received>0&&d.id!==${JSON.stringify(item.id)});`);
    await call(browser,"downloads.cancel",{id:cancel.id});
    await browser.until(`return globalThis.settingsDownloads.some(d=>d.id===${JSON.stringify(cancel.id)}&&d.state==="cancelled");`);
    assert.ok(!existsSync(join(folder,"slow (1).bin")));
    return "folder and ask persisted across relaunch; background save-panel path logged; chosen folder used; slow local download paused/resumed to 8 MiB; second cancelled; actual picker needs a person";
  },
  profiles: async ({browser,fixture}) => {
    const profile = "settings-work";
    await call(browser,"sites.setZoom",{profile,host:"127.0.0.1",zoom:1.5});
    await call(browser,"webKit.devTouchStore",{profile});
    const file = join(browser.data,"WebKit/Stores",createHash("sha256").update(profile).digest("hex")+".sqlite3");
    assert.ok(existsSync(file));
    assert.ok((await call(browser,"profiles.loaded")).profiles.includes(profile));
    await call(browser,"profiles.release",{profile});
    assert.ok(!(await call(browser,"profiles.loaded")).profiles.includes(profile));
    assert.deepEqual((await call(browser,"profiles.deleteData",{profile})).remaining,[]);
    assert.equal(existsSync(file),false); assert.equal(await call(browser,"webKit.devStoreExists",{profile}),false);
    await browser.open("/regular-cookie");
    const window = await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${JSON.stringify(fixture.origin+"/private-session")}});`);
    const tab = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(window)}&&t.title==="Cobalt Violet private-session");`);
    await browser.loaded(tab.id);
    await browser.page(tab.id,'(document.cookie="private=old;path=/",true)');
    const privateProfile = await browser.evaluate(`return ac.model.engineProfile(ac.store.getState(),${JSON.stringify(tab.profileId)});`);
    await set(browser,fixture.origin,"camera","block",privateProfile);
    await browser.evaluate(`ac.store.getState().closeWindow(${JSON.stringify(window)});return true;`);
    const second = await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${JSON.stringify(fixture.origin+"/private-session-2")}});`);
    const next = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${JSON.stringify(second)}&&t.title==="Cobalt Violet private-session-2");`);
    await browser.loaded(next.id);
    assert.equal(await browser.page(next.id,'document.cookie.includes("private=old")'),false);
    assert.equal((await settings(browser,fixture.origin,privateProfile)).camera.isDefault,true);
    assert.ok(readdirSync(join(browser.data,"WebKit/Stores")).every(name=>!name.includes("incognito")));
    await call(browser,"sites.setZoom",{profile:"",host:"127.0.0.1",zoom:1.25});
    assert.deepEqual((await call(browser,"profiles.deleteData",{profile:""})).remaining,[]);
    assert.equal(existsSync(browser.store),false);
    return "loaded/release reflect WebKit stores; profile deletion removed WebKit and SQLite; last private window cleared cookies and site settings; no private SQLite";
  },
  "search-engines": async ({browser,fixture}) => {
    await browser.open();
    for (const engine of ["google","duckduckgo","bing","kagi"]) {
      await browser.evaluate(`ac.store.getState().setSearchEngine(${JSON.stringify(engine)});return true;`);
      assert.equal(await browser.evaluate('return ac.store.getState().settings.searchEngine;'),engine);
    }
    const url = fixture.origin+"/custom-search?q=%s";
    const added = await browser.evaluate(`return ac.store.getState().addCustomEngine({name:"Local",keyword:"fixture",url:${JSON.stringify(url)}});`);
    assert.ok(!added.error,JSON.stringify(added));
    await browser.evaluate(`ac.store.getState().setSearchEngine(${JSON.stringify(added.id)});return true;`);
    await browser.restart(); await browser.type("step four query"); await browser.submit();
    const tab = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.url.includes("/custom-search?q=step%20four%20query"));`);
    await browser.loaded(tab.id);
    await browser.evaluate(`const s=ac.store.getState();s.updateSettings({customSearchEngines:s.settings.customSearchEngines.map(e=>({...e,suggestUrl:${JSON.stringify(fixture.origin+"/suggest?q=%s")}})),searchSuggestions:true});return true;`);
    await browser.type("step suggestions");
    await browser.until(`return ac.omnibox.get(${JSON.stringify(browser.driver)}).state().items.some(i=>i.suggested&&i.query==="fixture suggestion");`);
    const response = await call(browser,"search.suggest",{profile:"",id:42,url:fixture.origin+"/suggest?q=step"});
    assert.deepEqual(JSON.parse(response.body),["step",["fixture suggestion"]]);
    return "existing core list offers Google/DuckDuckGo/Bing/Kagi; custom choice survived relaunch and typed query loaded local URL; native suggestion transport used local fixture";
  },
  about: async ({browser}) => {
    const info = await call(browser,"engine.info");
    assert.equal(info.engine,"WebKit"); assert.match(info.webkitVersion,/\d/); assert.match(info.appVersion,/\d/);
    assert.equal(await browser.evaluate('return ac.engine.call("windows.list").then(w=>ac.engine.call("windows.dev",{window:w.find(w=>w.hasRoot).window,action:"about"}));'),"ok");
    const log = readFileSync(browser.app.log,"utf8");
    assert.ok(log.includes(`About: app=${info.appVersion} WebKit=${info.webkitVersion}`));
    const id = await browser.open(); await web(browser,id,"loadUrl",["ardia://version",true]);
    await browser.loaded(id,"Ardia WebKit Version");
    const text = await browser.page(id,"document.body.innerText");
    assert.ok(text.includes(info.webkitVersion)&&text.includes(info.appVersion)); assert.ok(!text.includes("Chromium"));
    return `engine.info and ardia://version show WebKit ${info.webkitVersion}, app ${info.appVersion}; no Chromium wording`;
  },
};
