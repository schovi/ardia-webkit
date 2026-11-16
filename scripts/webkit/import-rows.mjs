import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { Browser, BUILD, ROOT, run } from "./support.mjs";
import { RowOutcome } from "./report.mjs";

export const localImportRows = new Set(["import-arc-local", "import-chrome-local"]);
const json = JSON.stringify;
const fixtures = join(ROOT, "packages/import/fixtures/home/Library/Application Support");

export function copyImportProfile(source, destination) {
  mkdirSync(destination, {recursive:true});
  for (const name of ["Local State", "StorableSidebar.json", "Bookmarks", "AccountBookmarks", "History", "History-wal", "History-shm", "Preferences"]) {
    const path = join(source,name);
    if (existsSync(path)) copyFileSync(path,join(destination,name));
  }
  for (const entry of readdirSync(source,{withFileTypes:true})) {
    if (entry.isDirectory() && (entry.name === "User Data" || entry.name === "Default" || entry.name.startsWith("Profile "))) copyImportProfile(join(source,entry.name),join(destination,entry.name));
  }
}

async function wizard(browser, source, kinds) {
  await browser.evaluate('if(!globalThis.acImport)ac.runCommand({command:"importBrowserData"});return true;');
  await browser.until('return globalThis.acImport?.step==="choose";');
  assert.equal(await browser.evaluate(`return globalThis.acImport.select(${json(source)});`),true,"source not discovered");
  await browser.until(`return globalThis.acImport?.source===${json(source)};`);
  await browser.evaluate(`globalThis.acImport.setKinds(${json(kinds)});return true;`);
  await browser.evaluate('globalThis.acImport.next();return true;');
  const step = await browser.until('return ["profiles","unlock","done","progress"].includes(globalThis.acImport.step)&&globalThis.acImport.step;');
  if (step === "profiles") await browser.evaluate('globalThis.acImport.next();return true;');
  if (kinds.includes("cookies")) {
    await browser.until('return globalThis.acImport.step==="unlock";');
    await browser.evaluate('globalThis.acImport.unlock();return true;');
  }
  await browser.until('return globalThis.acImport.step==="done";',120000);
  const result = await browser.evaluate('const g=globalThis.acImport;return {counts:g.counts,failures:g.failures.map(f=>f.kind)};');
  assert.deepEqual(result.failures,[],"import kind failed");
  return result.counts;
}

async function importSource(context, source, kinds, local = false) {
  const {fixture,scratch,launches} = context;
  const directory = mkdtempSync(join(scratch,`import-${source}-${local ? "local" : "fixture"}-`));
  const copied = join(directory,"source");
  let support = fixtures;
  if (local) {
    const original = join(homedir(),"Library/Application Support",source === "arc" ? "Arc" : "Google/Chrome");
    if (!existsSync(original)) throw new RowOutcome("SKIPPED (no source profile)","local-only; source folder absent");
    support = copied;
    copyImportProfile(original,join(support,source === "arc" ? "Arc" : "Google/Chrome"));
  }
  const browser = new Browser(join(directory,"data"),fixture,launches,{importSourceDir:support});
  let stage="launch";
  try {
    await browser.launch();
    stage="read source";
    if(local) {
      const profiles=await browser.evaluate(`return globalThis.expo.modules.ArdiaImport.listBrowsers().then(raw=>JSON.parse(raw).find(b=>b.id===${json(source)})?.profiles.length??0);`);
      if(!profiles) throw new RowOutcome("SKIPPED (no source profile)","local-only; source folder exists but contains no importer-readable profile");
    }
    const expected = await browser.evaluate(`const m=globalThis.expo.modules.ArdiaImport;return m.listBrowsers().then(raw=>{const all=JSON.parse(raw);const source=all.find(b=>b.id===${json(source)});const profiles=${source === "arc" ? 'source.profiles' : '(source.profiles.filter(p=>p.isDefault).length?source.profiles.filter(p=>p.isDefault):source.profiles.slice(0,1))'};globalThis.importExpected=[];return profiles.reduce((chain,p)=>chain.then(()=>m.importData("expected-"+p.id,source.id,p.id,${json(kinds)},{})).then(raw=>{globalThis.importExpected.push(JSON.parse(raw));}),Promise.resolve());}).then(()=>{const flat=n=>[n,...(n.children??[]).flatMap(flat)];const results=globalThis.importExpected;return {spaces:results.reduce((n,r)=>n+r.spaces.length,0),tabs:results.reduce((n,r)=>n+r.tabs.length,0),pins:results.reduce((n,r)=>n+r.spaces.reduce((n,s)=>n+s.pinned.flatMap(flat).filter(x=>x.type==="url").length,0),0),folders:results.reduce((n,r)=>n+r.spaces.reduce((n,s)=>n+s.pinned.flatMap(flat).filter(x=>x.type==="folder").length,0),0),bookmarks:results.reduce((n,r)=>n+(r.bookmarks?flat(r.bookmarks).filter(x=>x.type==="url").length:0),0),history:results.reduce((n,r)=>n+r.history.length,0),visits:results.reduce((n,r)=>n+r.history.reduce((n,h)=>n+h.visits,0),0)};});`);
    if(local) {
      stage="privacy grep";
      const patterns = await browser.evaluate('const values=[];const visit=x=>{if(!x||typeof x!=="object")return;for(const [key,value] of Object.entries(x)){if(typeof value==="string"&&["url","title","name"].includes(key)&&value.length>=8&&!x.role&&value!=="Bookmarks")values.push(key==="url"?value:JSON.stringify(value));else if(typeof value==="object")visit(value);}};globalThis.importExpected.forEach(visit);return [...new Set(values)];');
      const patternFile=join(directory,"private-patterns.txt"), diffFile=join(directory,"commit-diff.patch");
      writeFileSync(patternFile,patterns.filter(value=>!value.includes("\n")).join("\n"));
      writeFileSync(diffFile,(await run("git",["diff","be094ea37","--","."])).text);
      const grep=spawnSync("grep",["-F","-f",patternFile,diffFile],{encoding:"utf8"});
      assert.equal(grep.status,1,"private source string found in patch");
      console.error(`privacy grep: matches=0; source strings=${patterns.length}; grep -F -f <scratch>/private-patterns.txt <scratch>/commit-diff.patch`);
    }
    stage="wizard";
    const start = Date.now();
    const counts = await wizard(browser,source,kinds);
    const elapsed = Date.now()-start;
    stage="destination comparison";
    if (source === "arc") {
      const proof = await browser.evaluate(`const s=ac.store.getState();const results=globalThis.importExpected;const flat=n=>[n,...(n.children??[]).flatMap(flat)];let spaces=0,matched=0,groups=0,order=true,themes=0;for(const r of results)for(const incoming of r.spaces){const profile=s.profileOrder[spaces++];const tabs=Object.values(s.tabs).filter(t=>t.profileId===profile);const expected=[...incoming.tabs,...incoming.pinned.flatMap(flat).filter(n=>n.type==="url")];matched+=expected.filter(n=>tabs.some(t=>t.url===n.url)).length;const window=s.windows[s.windowOrder[0]];const ordered=window.tabIds.map(id=>s.tabs[id]).filter(t=>t?.profileId===profile);const rows=incoming.pinned.filter(n=>n.type==="url");const rowPositions=rows.map(n=>ordered.findIndex(t=>t.url===n.url&&t.pin));order=order&&rowPositions.every((p,i)=>p>=0&&(i===0||p>=rowPositions[i-1]));if(incoming.theme&&s.profiles[profile].theme)themes++;for(const folder of incoming.pinned.flatMap(flat).filter(n=>n.type==="folder"&&n.role!=="split")){const links=flat(folder).filter(n=>n.type==="url");if(!links.length)continue;const group=Object.values(s.groups).find(g=>g.profileId===profile&&g.name===folder.title);if(group&&links.every(n=>group.tabIds.some(id=>s.tabs[id]?.url===n.url))){groups++;const positions=links.map(n=>group.tabIds.findIndex(id=>s.tabs[id]?.url===n.url));order=order&&positions.every((p,i)=>i===0||p>=positions[i-1]);}}}return {spaces,matched,groups,order,themes,profiles:s.profileOrder.length};`);
      assert.equal(proof.order,true,"pin or folder order differs");
      assert.equal(proof.spaces,expected.spaces,"space count differs");
      assert.equal(proof.matched,expected.tabs+expected.pins,"source tab absent from destination");
      assert.ok(proof.profiles>=expected.spaces,"space destinations missing");
      await browser.evaluate('globalThis.acImport.close();return true;');
      const evidence=join(BUILD,"step-6-evidence");mkdirSync(evidence,{recursive:true});
      await browser.snapshot("arc-sidebar.png");
      copyFileSync(join(browser.data,"arc-sidebar.png"),join(evidence,local?"arc-local-sidebar.png":"arc-fixture-sidebar.png"));
      return `${local?"local-only; ":"fixture; "}source spaces=${expected.spaces}, tabs=${expected.tabs}, pinned tabs=${expected.pins}, folders=${expected.folders}; matched tabs=${proof.matched}, destination spaces=${proof.spaces}, folders=${proof.groups}, themes=${proof.themes}; relative order preserved; wrote tabs=${counts.tabs}; ${elapsed} ms`;
    }
    if(kinds.includes("bookmarks")) {
      await browser.until(`return ac.engine.call("bookmarks.tree",{profile:""}).then(t=>{const flat=n=>[n,...(n.c??[]).flatMap(flat)];return flat(t.bar).concat(flat(t.other)).filter(n=>n.k==="u").length===${expected.bookmarks};});`);
      assert.equal(counts.bookmarks,expected.bookmarks);
      assert.equal(await browser.evaluate('return ac.engine.call("bookmarks.tree",{profile:""}).then(t=>{const native=n=>n.k==="u"?{title:n.t,url:n.u}:{title:n.t,children:(n.c??[]).map(native)};const source=n=>n.type==="url"?{title:n.title,url:n.url}:{title:n.title,children:(n.children??[]).map(source)};const roots=globalThis.importExpected[0].bookmarks.children;const bar=roots.filter(n=>n.role==="toolbar").flatMap(n=>n.children??[]);const other=roots.filter(n=>n.role!=="toolbar").flatMap(n=>(n.role==="other"||!n.role)?(n.children??[n]):[n]);return JSON.stringify(t.bar.c.map(native))===JSON.stringify(bar.map(source))&&JSON.stringify(t.other.c.map(native))===JSON.stringify(other.map(source));});'),true,"bookmark hierarchy or order differs");

    }
    if(kinds.includes("history")) {
      await browser.until(`return ac.engine.call("history.query",{profile:"",maxUrls:50000,maxVisits:1}).then(r=>globalThis.importExpected.every(source=>source.history.every(h=>r.entries.some(e=>e.u===h.url&&e.t===h.title&&e.n===h.visits&&e.v.includes(h.lastVisit)))));`,120000);
      assert.equal(Number(await browser.sql("SELECT COALESCE(SUM(visits),0) FROM pages;")),expected.visits);
    }
    await browser.restart();
    const persisted = await browser.sql("SELECT (SELECT COUNT(*) FROM pages)||','||(SELECT COUNT(*) FROM bookmarks WHERE json_extract(value,'$.k')='u');");
    return `${local?"local-only; ":"fixture; "}source bookmarks=${expected.bookmarks}, history entries=${expected.history}, visits=${expected.visits}; wrote bookmarks=${counts.bookmarks}, history entries=${counts.history}; SQLite after relaunch=${persisted}; ${elapsed} ms`;
  } catch (error) {
    if(error instanceof RowOutcome) throw error;
    if(local) throw new Error(`local-only import failed during ${stage}; classification=${["undefined","null","notFound","unsupported","SyntaxError","unreadable","Cannot","profile"].filter(word=>error.message.includes(word)).join(",")}; details withheld to protect profile data`);
    throw error;
  } finally {
    try {await browser.stop();}
    finally {if(local) {rmSync(copied,{recursive:true,force:true});assert.equal(existsSync(copied),false);console.error(`profile copy removed: ${copied}; listing=${JSON.stringify(readdirSync(directory).filter(name=>name==="source"))}`);}}
  }
}

export const importRows = {
  "import-arc-spaces": context=>importSource(context,"arc",["spaces","pinnedTabs","tabs"]),
  "import-arc-tabs": context=>importSource(context,"arc",["spaces","pinnedTabs","tabs"]),
  "import-bookmarks": context=>importSource(context,"chrome",["bookmarks"]),
  "import-history": context=>importSource(context,"chrome",["history"]),
  "import-arc-local": context=>importSource(context,"arc",["spaces","pinnedTabs","tabs"],true),
  "import-chrome-local": context=>importSource(context,"chrome",["bookmarks","history"],true),
  "import-cookies": async ({scratch,fixture,launches})=>{
    const directory=join(scratch,"cookies-source");
    await run("python3",["packages/import/scripts/e2e_fixture.py",directory,"e2e-test-secret",new URL(fixture.origin).port]);
    const browser=new Browser(join(scratch,"cookie-data"),fixture,launches,{importSourceDir:join(directory,"Library/Application Support"),importSecret:"e2e-test-secret"});
    try {
      await browser.launch();
      const refused=await browser.evaluate('const m=globalThis.expo.modules.ArdiaImport;return m.unlockBrowser("chrome",null).then(()=>m.importData("private-cookie","chrome","Default",["cookies"],{})).then(JSON.parse).then(r=>m.writeImported(r.vaultToken,"incognito-test",["cookies"])).then(JSON.parse);');
      assert.equal(refused.cookies,0);assert.equal(refused.cookiesFailed,1);
      await browser.evaluate('globalThis.expo.modules.ArdiaImport.forgetUnlockedKeys();return true;');
      const counts=await wizard(browser,"chrome",["cookies"]);
      assert.ok(counts.cookies>0);
      const tab=await browser.open(fixture.origin.replace("127.0.0.1","localhost")+"/import-cookie");
      assert.equal(await browser.page(tab,'document.cookie.includes("ac_session=until-quit")'),true);
      assert.ok(fixture.cookies.some(cookie=>cookie.includes("ac_session=until-quit")),"server did not receive imported cookie");
      return `fixture; wrote cookies=${counts.cookies}; next request sent imported session cookie; no Keychain`;
    } finally {await browser.stop();}
  },
  "import-honest": async ({scratch,fixture,launches})=>{
    const browser=new Browser(join(scratch,"honest-data"),fixture,launches,{importSourceDir:fixtures});
    try {
      await browser.launch();
      await browser.evaluate('if(!globalThis.acImport)ac.runCommand({command:"importBrowserData"});return true;');
      await browser.until('return globalThis.acImport?.step==="choose";');
      await browser.evaluate('globalThis.acImport.select("chrome");return true;');
      const kinds=await browser.evaluate('return globalThis.acImport.kinds;');
      assert.ok(!kinds.includes("passwords")&&!kinds.includes("autofill"));
      const counts=await wizard(browser,"chrome",["bookmarks","passwords","autofill"]);
      assert.equal(counts.passwords+counts.addresses+counts.cards,0);
      assert.ok(await browser.evaluate('return globalThis.acPerf.findFibers("Text").some(f=>typeof f.memoizedProps.children==="string"&&f.memoizedProps.children.includes("were not imported"));'));
      return "fixture; passwords=0, addresses=0, cards=0; selection hidden; result says not imported";
    } finally {await browser.stop();}
  },
};
