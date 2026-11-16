import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { BUILD, sleep } from "./support.mjs";

const evidence = join(BUILD, "step-2-evidence");
async function native(browser, action) {
  return browser.evaluate(`return ac.engine.call("windows.list").then(w=>ac.engine.call("windows.dev",{window:w.find(w=>w.hasRoot).window,action:${JSON.stringify(action)}}));`);
}
const state = async browser => JSON.parse(await native(browser, "state"));
const keyCodes = Object.fromEntries(Object.entries({a:0,s:1,d:2,f:3,h:4,g:5,z:6,x:7,c:8,v:9,b:11,q:12,w:13,e:14,r:15,y:16,t:17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"=":24,"9":25,"7":26,"-":27,"8":28,"0":29,"]":30,o:31,u:32,"[":33,i:34,p:35,l:37,j:38,"'":39,k:40,";":41,":":41,"\\":42,",":43,"/":44,n:45,m:46,".":47," ":49}));
async function key(browser, text, code = keyCodes[text.toLowerCase()] ?? 0, modifiers = 0) {
  assert.equal(await native(browser, `key:${text}|${code}|${modifiers}`), "ok");
  await sleep(150);
}
async function click(browser, point, right = false) {
  for (const phase of ["down", "up"]) {
    await native(browser, `mouse:${right ? "right" : ""}${phase},${point.x},${point.y}`);
    await sleep(100);
  }
}
async function point(browser, id, selector) {
  const rect = await browser.page(id, `(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()`);
  const page = (await state(browser)).pages[0];
  assert.ok(page);
  return {x: page.x + rect.x, y: page.y + rect.y};
}
async function inputs(browser) {
  const id = await browser.open("/keyboard");
  await browser.execute(id, 'document.body.innerHTML=\'<input id="first"><input id="second"><a id="link" href="/context-child">Link</a>\';document.addEventListener("keydown",e=>document.documentElement.dataset.lastKey=e.key);');
  await browser.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(!!document.querySelector("#first")));');`);
  return id;
}
async function snapshot(browser, name) {
  mkdirSync(evidence, {recursive:true});
  await browser.snapshot(name);
  copyFileSync(join(browser.data, name), join(evidence, name));
}
export const windowRows = {
  "type-page": async ({browser}) => {
    const id = await inputs(browser);
    await click(browser, await point(browser,id,"#first"));
    for (const letter of "hello") await key(browser,letter);
    assert.equal(await browser.page(id,'document.querySelector("#first").value'), "hello", `native key dispatch did not type into WebKit; responder=${(await state(browser)).responder}; needs a person`);
    await key(browser,"a",0,1048576); await key(browser,"c",8,1048576);
    await key(browser,"\t",48); await key(browser,"v",9,1048576);
    assert.equal(await browser.page(id,'document.activeElement.id'),"second");
    assert.equal(await browser.page(id,'document.querySelector("#second").value'),"hello");
    return "synthetic click, native keys: hello; Tab to second; Cmd+C/V copied hello; system focus needs a person";
  },
  "type-omnibox": async ({browser}) => {
    const id = await browser.open();
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).focus();`);
    await key(browser,"l",37,1048576);
    const driver = await browser.until(`return ac.omnibox.ids().find(id=>id.startsWith(${JSON.stringify(browser.window+":")}));`);
    for (const letter of browser.fixture.origin+"/key-url") await key(browser,letter);
    assert.equal(await browser.evaluate(`return ac.omnibox.get(${JSON.stringify(driver)}).state().typed;`),browser.fixture.origin+"/key-url");
    await key(browser,"\r",36);
    await browser.loaded(id,"Cobalt Violet key-url");
    await key(browser,"l",37,1048576); await key(browser,"\u001b",53);
    assert.match((await state(browser)).responder,/WK/);
    return "synthetic Cmd+L; native URL typing and Return loaded fixture; Esc restored WK responder; system focus needs a person";
  },
  "keys-page-focus": async ({browser}) => {
    const id = await inputs(browser);
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).focus();`);
    await key(browser,"t",17,1048576);
    await browser.until('return Object.keys(ac.store.getState().tabs).length===2;');
    await key(browser,"w",13,1048576);
    await browser.until('return Object.keys(ac.store.getState().tabs).length===1;');
    await browser.activate(id);
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).focus();`);
    await key(browser,"f",3,1048576);
    await browser.until(`return !!ac.store.getState().find[${JSON.stringify(id)}];`);
    await key(browser,"\u001b",53);
    await browser.execute(id,'document.documentElement.dataset.marker="before"');
    await key(browser,"r",15,1048576);
    await browser.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(!document.documentElement.dataset.marker));');`);
    await browser.execute(id,'location.href="/second"'); await browser.loaded(id,"Cobalt Violet second");
    await key(browser,"[",33,1048576); await browser.loaded(id,"Cobalt Violet keyboard");
    await key(browser,"]",30,1048576); await browser.loaded(id,"Cobalt Violet second");
    await browser.execute(id,'document.addEventListener("keydown",e=>document.documentElement.dataset.key=e.key)');
    await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).focus();`); await key(browser,"x",7);
    assert.equal(await browser.page(id,"document.documentElement.dataset.key"),"x");
    return "synthetic Cmd+T/W/R/F/[/] changed tabs, reload, find and history; plain x reached DOM; system routing needs a person";
  },
  "traffic-lights": async ({browser}) => {
    await browser.open();
    const set = async (x,y,trailing=false) => browser.evaluate(`return ac.shell.setTrafficLightsCenter(${JSON.stringify(browser.window)},[${x},${y}${trailing ? ",\"right\"" : ""}]);`);
    await sleep(500);
    await set(40,30);
    assert.deepEqual((await state(browser)).lights[0],[40,30]);
    await native(browser,"resize:1100,740");
    await sleep(500);
    await set(40,30);
    assert.deepEqual((await state(browser)).lights[0],[40,30]);
    await browser.evaluate(`ac.runCommand({command:"toggleSidebar",arg:null,windowId:${JSON.stringify(browser.window)}});return true;`);
    await sleep(500);
    await set(40,30);
    const actual = (await state(browser)).lights;
    assert.deepEqual(actual[0],[40,30]);
    assert.equal(actual.length,3); assert.ok(actual[1][0]>actual[0][0]&&actual[2][0]>actual[1][0]);
    await snapshot(browser,"normal.png");
    return `explicit close center=[40,30] honored before and after resize/sidebar toggle; lights=${JSON.stringify(actual)}; normal.png retained; visible layout needs a person`;
  },
  "close-window": async ({browser}) => {
    await browser.open();
    assert.equal(await native(browser,"close"),"ok");
    await browser.until('return ac.shell.windowIds().then(ids=>ids.length===0);');
    assert.equal(await browser.evaluate('return ac.store.getState().windowOrder.length;'),0);
    assert.ok(browser.app.alive);
    return "native performClose -> shouldCloseHandler -> JS closeRequest; store and native windows=0; app alive";
  },
  "full-screen": async ({browser}) => {
    await browser.open();
    await native(browser,"fullscreen");
    await browser.until(`return ac.store.getState().windows[${JSON.stringify(browser.window)}].fullScreen;`);
    await snapshot(browser,"fullscreen.png");
    await native(browser,"fullscreen");
    await browser.until(`return !ac.store.getState().windows[${JSON.stringify(browser.window)}].fullScreen;`);
    throw new Error("window full screen enter/exit notifications and snapshot proven in hidden simulation; WebKit disables element full screen in background mode; native element transition and chrome hiding need a person");
  },
  "user-sees": async ({browser}) => {
    await browser.open();
    assert.equal((await state(browser)).seen,true);
    return "visible hidden-test window reports seen=true; automatic PiP now has a visible baseline; real occlusion needs a person";
  },
  "profile-switch": async ({browser}) => {
    const first = await browser.open("/cookies");
    await browser.page(first,'(document.cookie="step2=personal;path=/",true)');
    const profile = await browser.evaluate('return ac.store.getState().createProfile({name:"Keyboard Work"});');
    await browser.evaluate(`ac.store.getState().switchProfile(${JSON.stringify(browser.window)},${JSON.stringify(profile)});return true;`);
    const second = await browser.open("/cookies");
    assert.ok(!(await browser.page(second,"document.cookie")).includes("step2=personal"));
    await browser.page(second,'(document.cookie="step2=work;path=/",true)');
    await browser.evaluate(`ac.store.getState().switchProfile(${JSON.stringify(browser.window)},"default");return true;`);
    await browser.activate(first);
    assert.ok((await browser.page(first,"document.cookie")).includes("step2=personal"));
    return "same window switched profile; work initially isolated, then work cookie; personal cookie survived return";
  },
  swipe: async ({browser}) => {
    await browser.open();
    assert.equal((await state(browser)).pages[0].gestures,true);
    throw new Error("allowsBackForwardNavigationGestures=true; two-finger trackpad gesture needs a person; synthetic input cannot prove macOS gesture recognition");
  },
  "context-menu": async ({browser}) => {
    const id = await inputs(browser);
    await click(browser,await point(browser,id,"#link"),true);
    const path = join(browser.data,"context-menu.json");
    let items;
    for (const end=Date.now()+5000;Date.now()<end;await sleep(100)) {
      try { items=JSON.parse(readFileSync(path,"utf8")); break; } catch {}
    }
    assert.ok(items,"synthetic right-click did not produce a WebKit menu; needs a person");
    assert.ok(items.some(i=>i.title==="Open Link in New Tab"));
    assert.ok(items.some(i=>/Copy Link/.test(i.title)));
    writeFileSync(path+".pick","Open Link in New Tab");
    await click(browser,await point(browser,id,"#link"),true);
    await browser.until('return Object.values(ac.store.getState().tabs).some(t=>t.title==="Cobalt Violet context-child");');
    await browser.activate(id);
    rmSync(path,{force:true});
    writeFileSync(path+".pick",items.find(i=>/Copy Link/.test(i.title)).title);
    await click(browser,await point(browser,id,"#link"),true);
    await browser.until('return ac.shell.readText().then(text=>text.endsWith("/context-child"));');
    assert.equal(await browser.evaluate('return ac.shell.readText();'),browser.fixture.origin+"/context-child");
    rmSync(path,{force:true});
    const page = (await state(browser)).pages[0];
    await click(browser,{x:page.x+500,y:page.y+300},true);
    let pageItems;
    for(const end=Date.now()+5000;Date.now()<end;await sleep(100)) {
      try { pageItems=JSON.parse(readFileSync(path,"utf8")); break; } catch {}
    }
    assert.ok(pageItems?.length,"page menu did not appear");
    assert.ok(!pageItems.some(i=>i.title==="Open Link in New Tab"));
    return `synthetic right-click link menu=${items.map(i=>i.title).join(",")}; open tab and copy link proven; page menu=${pageItems.map(i=>i.title).join(",")}; real mouse needs a person`;
  },
};
