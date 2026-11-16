import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { RowOutcome } from "./report.mjs";

const state = (browser, id) => browser.evaluate(`return ac.engine.call("webKit.devPageState",{tabId:${JSON.stringify(id)}});`);
const call = (browser, name, args) => browser.evaluate(`return ac.engine.call(${JSON.stringify(name)},${JSON.stringify(args)});`);
const web = (browser, id, method, args = []) => browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).${method}(${args.map(JSON.stringify).join(",")});`);

export const pageRows = {
  inspector: async ({browser}) => {
    const id = await browser.open();
    assert.equal((await state(browser,id)).inspectable,true);
    await web(browser,id,"showDevTools",["inspect"]);
    await browser.evaluate(`ac.runCommand({command:"devTools",arg:null,windowId:${JSON.stringify(browser.window)}});return true;`);
    const log = readFileSync(browser.app.log,"utf8");
    assert.match(log,/inspector inspect \(background mode, not shown\)/);
    assert.match(log,/inspector default \(background mode, not shown\)/);
    throw new RowOutcome("NEEDS PERSON","Inspect and Developer Tools command reached private _inspector; selectors present; inspectable=true; background mode suppressed UI; actual inspector and shortcut need a key window");
  },
  "popup-blocked": async ({browser}) => {
    const id = await browser.open("/popup-auto");
    const popup = await browser.until(`return ac.pageState.getState().pages[${JSON.stringify(id)}]?.popups?.[0];`);
    assert.equal(popup.url,browser.fixture.origin+"/automatic-child");
    assert.equal(popup.origin,browser.fixture.origin);
    assert.equal(await browser.evaluate('return Object.keys(ac.store.getState().tabs).length;'),1);
    await web(browser,id,"openBlockedPopup",[popup.id,false]);
    const child = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet automatic-child");');
    await browser.activate(id);
    await web(browser,id,"reload");
    const second = await browser.until(`return ac.pageState.getState().pages[${JSON.stringify(id)}]?.popups?.find(p=>p.id!==${JSON.stringify(popup.id)});`);
    await web(browser,id,"openBlockedPopup",[second.id,true]);
    await browser.restart();
    await browser.open("/popup-auto");
    await browser.until(`return Object.values(ac.store.getState().tabs).filter(t=>t.title==="Cobalt Violet automatic-child").length>=3;`);
    return `timer popup blocked; UI received id/url/origin; open once loaded ${child.title}; Always allow survived relaunch`;
  },
  "http-auth": async ({browser}) => {
    const id = await browser.open();
    await web(browser,id,"loadUrl",[browser.fixture.origin+"/auth",true]);
    await browser.until(`return ac.engine.call("webKit.devHTTPAuth",{tabId:${JSON.stringify(id)}});`);
    assert.match(readFileSync(browser.app.log,"utf8"),/HTTP auth prompt:/);
    await call(browser,"webKit.devHTTPAuth",{tabId:id,action:"answer",username:"fixture",password:"wrong"});
    await browser.until(`return ac.engine.call("webKit.devHTTPAuth",{tabId:${JSON.stringify(id)}});`);
    await call(browser,"webKit.devHTTPAuth",{tabId:id,action:"answer",username:"fixture",password:"correct"});
    await browser.loaded(id,"Cobalt Violet auth");
    await browser.restart();
    const cancelled = await browser.open();
    await web(browser,cancelled,"loadUrl",[browser.fixture.origin+"/auth-cancel",true]);
    await browser.until(`return ac.engine.call("webKit.devHTTPAuth",{tabId:${JSON.stringify(cancelled)}});`);
    await call(browser,"webKit.devHTTPAuth",{tabId:cancelled,action:"answer"});
    await browser.loaded(cancelled,"Unauthorized");
    assert.match(await browser.page(cancelled,"document.body.innerText"),/401 Unauthorized/);
    return "Basic challenge logged; wrong credentials re-prompted; correct credentials loaded; Cancel displayed actual 401 body; sheet input needs a person";
  },
  "load-error": async ({browser,fixture}) => {
    const id = await browser.open();
    await web(browser,id,"loadUrl",[fixture.refusedOrigin+"/refused",true]);
    await browser.loaded(id,"Can't Open This Page");
    assert.equal(await browser.page(id,'!!document.querySelector("#retry")'),true);
    assert.equal(await browser.evaluate(`return ac.store.getState().tabs[${JSON.stringify(id)}].url;`),fixture.refusedOrigin+"/refused");
    for (const code of [-1003,-1009]) {
      await call(browser,"webKit.devPageFailure",{tabId:id,url:fixture.origin+"/retry-target",code});
      await browser.loaded(id,"Can't Open This Page");
      await browser.execute(id,'document.querySelector("#retry").click()');
      await browser.loaded(id,"Cobalt Violet retry-target");
    }
    return "real refused loopback connection rendered error; injected DNS/offline errors used same delegate; Retry loaded local fixture; failed URL/title preserved";
  },
  "page-colors": async ({browser}) => {
    await browser.evaluate('ac.store.getState().updateSettings({appearance:"dark"});return true;');
    const id = await browser.open();
    const colors = await state(browser,id);
    assert.ok(colors.pageColor);
    assert.match(colors.backgroundColor,/^#[0-9A-F]{6}$/);
    const rgb = colors.backgroundColor.slice(1).match(/../g).map(value=>parseInt(value,16));
    assert.ok(Math.max(...rgb)<200,JSON.stringify(colors));
    return `native background=${colors.backgroundColor}; pageColor=${colors.pageColor}; dark backing installed at attach; white flash needs visual check`;
  },
  "little-ardia": async ({browser}) => {
    await browser.open();
    await browser.evaluate('ac.store.getState().updateSettings({openLinksInLittleArdia:true});return true;');
    await call(browser,"webKit.devOpenURLs",{urls:[browser.fixture.origin+"/external"]});
    const tab = await browser.until('return Object.values(ac.store.getState().tabs).find(t=>t.title==="Cobalt Violet external");');
    await browser.loaded(tab.id,"Cobalt Violet external");
    assert.equal(await browser.evaluate(`return ac.store.getState().windows[${JSON.stringify(tab.windowId)}].kind;`),"small");
    await browser.execute(tab.id,'document.documentElement.dataset.transfer="kept"');
    await browser.evaluate(`ac.runCommand({command:"openFile",arg:null,windowId:${JSON.stringify(tab.windowId)}});return true;`);
    await browser.until(`const t=ac.store.getState().tabs[${JSON.stringify(tab.id)}];return t&&t.windowId!==${JSON.stringify(tab.windowId)};`);
    await browser.loaded(tab.id,"Cobalt Violet external");
    assert.equal(await browser.page(tab.id,'document.documentElement.dataset.transfer'),"kept");
    return "native application URL delivery opened small window; Open in Ardia moved same live DOM to main window";
  },
};
