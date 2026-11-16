import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { join } from "node:path";
import { BUILD, sleep } from "./support.mjs";

const json = JSON.stringify;
async function tree(browser, profile = "") {
  return browser.evaluate(`return ac.engine.call("bookmarks.tree",{profile:${json(profile)}});`);
}
async function ready(browser) {
  await browser.until('return ac.store.getState().bookmarksReady[""];');
  await browser.evaluate('ac.store.getState().updateSettings({showBookmarks:true,bookmarksBar:"always",hideBookmarksBarImport:true});return true;');
}
async function seed(browser) {
  await ready(browser);
  const ids = await browser.evaluate(`const s=ac.store.getState();const folder=s.addBookmarkFolder({profileId:"default",title:"Reading"});const links=s.addBookmarkTree("default",["One","Two","Three"].map(title=>({title,url:${json(browser.fixture.origin)}+"/"+title.toLowerCase()})));return {folder,links};`);
  await browser.until(`return ac.engine.call("bookmarks.tree",{profile:""}).then(t=>t.bar.c.length===4);`);
  return ids;
}
async function saved(browser, expression) {
  return browser.until(`return ac.engine.call("bookmarks.tree",{profile:""}).then(t=>${expression});`);
}

export const bookmarkRows = {
  "bookmark-add": async ({browser}) => {
    const tab = await browser.open("/bookmark-ui");
    await ready(browser);
    await browser.evaluate(`ac.runCommand({command:"bookmarkPage",arg:null,windowId:${json(browser.window)}});return true;`);
    const dialog = await browser.until('return ac.menus.useBookmarkDialog.getState().open;');
    assert.equal(dialog.kind,"page");
    await browser.until('return globalThis.acPerf.findFibers("DialogPanel").length>0;');
    assert.equal(await browser.evaluate(`return ac.store.getState().bookmarks.nodes[${json(dialog.bookmarkId)}].url;`), browser.fixture.origin+"/bookmark-ui");
    await saved(browser, `t.bar.c.some(n=>n.id===${json(dialog.bookmarkId)})`);
    await browser.until(`return globalThis.acPerf.findFibers("BarItem").some(f=>f.memoizedProps.id===${json(dialog.bookmarkId)});`);
    await browser.evaluate('const done=globalThis.acPerf.findFibers("Button").find(f=>f.memoizedProps.title==="Done");if(!done)throw Error("Done button missing");done.memoizedProps.onPress();return true;');
    await browser.until('return ac.menus.useBookmarkDialog.getState().open===null;');
    assert.ok(await browser.page(tab,'document.title'));
    return "Add to Bookmarks command opened Bookmark Added dialog; Done closed it; native tree and mounted bar contain page";
  },
  "bookmark-folder": async ({browser}) => {
    await browser.open();
    const {folder,links} = await seed(browser);
    await browser.evaluate(`const s=ac.store.getState();s.moveBookmark(${json(links[0])},${json(folder)},0);s.moveBookmark(${json(links[1])},${json(folder)},0);s.updateBookmark(${json(folder)},{title:"Saved reading"});return true;`);
    await saved(browser, `t.bar.c[0].t==="Saved reading"&&t.bar.c[0].c[0]?.id===${json(links[1])}&&t.bar.c[0].c[1]?.id===${json(links[0])}`);
    await browser.evaluate(`ac.store.getState().moveBookmark(${json(links[2])},"bar@default",0);return true;`);
    await saved(browser, `t.bar.c[0].id===${json(links[2])}`);
    assert.equal(await browser.sql(`SELECT group_concat(position,',') FROM (SELECT position FROM bookmarks WHERE parent='${folder}' ORDER BY position);`),"0,1");
    await browser.evaluate(`ac.store.getState().removeBookmark(${json(folder)});return true;`);
    await saved(browser, `t.bar.c.length===1&&t.bar.c[0].id===${json(links[2])}`);
    assert.equal(await browser.sql("SELECT COUNT(*) FROM bookmarks;"),"3");
    return "folder created/renamed; moveBookmark (drag completion action) reordered within folder and bar; SQLite order 0,1; folder deletion removed both children";
  },
  "bookmark-persist": async ({browser}) => {
    await browser.open(); await seed(browser);
    const before = await tree(browser);
    assert.equal(await browser.sql("SELECT COUNT(*) FROM bookmarks;"),"6");
    const evidence = join(BUILD,"step-5-evidence"); mkdirSync(evidence,{recursive:true});
    await browser.until('return globalThis.acPerf.findFibers("BarItem").length===4;');
    await sleep(500); await browser.snapshot("bookmarks-bar.png");
    copyFileSync(join(browser.data,"bookmarks-bar.png"),join(evidence,"bookmarks-bar.png"));
    await browser.stop();
    rmSync(join(browser.data,"bookmarks-cache.json"),{force:true});
    await browser.launch(); await ready(browser);
    assert.deepEqual(await tree(browser),before);
    await browser.until(`return ${json(before.bar.c.map(n=>n.id))}.every(id=>ac.store.getState().bookmarks.nodes[id]);`);
    assert.equal(await browser.sql("SELECT COUNT(*) FROM bookmarks;"),"6");
    return "folder + three links; 6 SQLite rows; removed JS cache; UUIDs, timestamps and order identical after relaunch; snapshot="+join(evidence,"bookmarks-bar.png");
  },
  "bookmark-export": async ({browser}) => {
    await browser.open(); const {folder,links} = await seed(browser);
    const title = 'Café <tag> & "quotes"';
    const url = browser.fixture.origin+'/one?a=1&b=%22quoted%22';
    await browser.evaluate(`const s=ac.store.getState();s.updateBookmark(${json(links[0])},{title:${json(title)},url:${json(url)}});s.moveBookmark(${json(links[1])},${json(folder)},0);s.moveBookmark(${json(links[2])},"other@default",0);return true;`);
    await saved(browser, `t.bar.c.length===2&&t.bar.c[0].c.length===1&&t.other.c.length===1`);
    const path = await browser.evaluate('return ac.engine.call("bookmarks.exportHtml",{profile:""});');
    assert.ok(path.startsWith(browser.data+"/"));
    const html = readFileSync(path,"utf8");
    assert.match(html,/NETSCAPE-Bookmark-file-1/); assert.match(html,/&lt;tag&gt; &amp; &quot;quotes&quot;/);
    const parsed = await browser.evaluate(`return globalThis.expo.modules.ArdiaImport.importBookmarksHTML(${json(path)}).then(JSON.parse);`);
    const flatten = node => [node,...(node.children??node.c??[]).flatMap(flatten)];
    const nodes = flatten(parsed), native = flatten({children:[(await tree(browser)).bar,(await tree(browser)).other]});
    assert.equal(nodes.filter(n=>n.type==="url").length,3);
    for (const node of native.filter(n=>n.k==="u")) assert.ok(nodes.some(n=>n.url===node.u&&n.title===node.t&&n.dateAdded===Math.floor(node.a/1000)*1000));
    assert.ok(nodes.some(n=>n.title==="Reading"&&n.children?.[0]?.title==="Two"));
    assert.equal(parsed.children[0].role,"toolbar"); assert.equal(parsed.children[1].role,"other");
    return "public exportHtml wrote Netscape HTML without panel; real import parser recovered all 3 URLs/titles/dates, nested folder, bar/other roles, UTF-8 and escaped attributes";
  },
  "bookmark-profile": async ({browser}) => {
    await browser.open(); await seed(browser);
    const before = await tree(browser);
    await browser.evaluate('globalThis.bookmarkEvents=[];ac.engine.on("bookmarks.changed",e=>globalThis.bookmarkEvents.push(e));return ac.engine.call("bookmarks.watch",{profile:"bookmark-work"});');
    await browser.evaluate('return ac.engine.call("bookmarks.watch",{profile:"bookmark-work"});');
    const other = await tree(browser,"bookmark-work"); assert.equal(other.bar.c.length,0);
    await browser.until('return globalThis.bookmarkEvents.some(e=>e.profile==="bookmark-work");');
    assert.deepEqual(await browser.evaluate('return globalThis.bookmarkEvents;'),[{profile:"bookmark-work"}]);
    const id = "20000000-0000-4000-8000-000000000001";
    assert.deepEqual(await browser.evaluate(`return ac.engine.call("bookmarks.apply",{profile:"bookmark-work",ops:[{op:"add",id:${json(id)},k:"u",u:"https://work.example/",t:"Work",a:1234,parent:"bar"}]});`),{applied:1,skipped:0,invalid:[]});
    await sleep(300);
    assert.deepEqual(await browser.evaluate('return globalThis.bookmarkEvents;'),[{profile:"bookmark-work"}],"apply suppresses changed events as Chromium does");
    assert.deepEqual(await tree(browser),before);
    await browser.restart();
    assert.equal((await tree(browser,"bookmark-work")).bar.c[0].id,id);
    assert.deepEqual(await tree(browser),before);
    return "second profile initially empty; independent persisted tree; watch idempotent, model-load event={profile}; apply suppresses events per Chromium";
  },
  "bookmark-private": async ({browser}) => {
    await browser.open(); await seed(browser);
    const before = await tree(browser);
    const files = readdirSync(join(browser.data,"WebKit/Stores")).filter(n=>n.endsWith(".sqlite3"));
    const window = await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${json(browser.fixture.origin+"/private-bookmarks")}});`);
    const tab = await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${json(window)}&&t.title==="Cobalt Violet private-bookmarks");`);
    const profile = await browser.evaluate(`const s=ac.store.getState();return ac.model.engineProfile(s,${json(tab.profileId)});`);
    assert.deepEqual(await tree(browser,profile),before);
    const state = await browser.evaluate(`const s=ac.store.getState();return {profile:ac.model.bookmarkProfileId(s,s.windows[${json(window)}]),bar:s.bookmarks.nodes["bar@default"]};`);
    assert.equal(state.profile,"default"); assert.equal(state.bar.children.length,4);
    assert.equal(await browser.evaluate(`return globalThis.acPerf.findFibers("BarItem").filter(f=>f.memoizedProps.windowId===${json(window)}).length;`),0);
    assert.deepEqual(readdirSync(join(browser.data,"WebKit/Stores")).filter(n=>n.endsWith(".sqlite3")),files);
    assert.deepEqual(await tree(browser),before);
    return "private window resolves bookmarks to base profile; native tree equals base; upstream intentionally hides private bar; no private SQLite; base unchanged";
  },
};
