import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { run, sleep } from "./support.mjs";
import { titleOf } from "./fixture.mjs";

const json = JSON.stringify;
const password = "fixture-webkit-pass";
const updated = "fixture-webkit-updated";
const call = (browser, name, args = {}) => browser.evaluate(`return ac.engine.call(${json(name)},${json({profile:"",...args})});`);
const moduleCall = (browser, name, args) => browser.evaluate(`return globalThis.expo.modules.ArdiaPasswords.${name}(${args.map(json).join(",")}).then(JSON.parse);`);
const list = browser => call(browser,"passwords.list").then(result=>result.passwords);
const prompt = (browser,id) => browser.until(`return ac.pageState.getState().pages[${json(id)}]?.passwordPrompt;`);
const answer = (browser,id,action) => browser.evaluate(`return ac.webviews.get(${json(id)}).resolvePasswordPrompt(${json(action)});`);
const submit = (browser,id,secret=password,user="fixture") => browser.execute(id,`const user=document.querySelector('#username');if(user)user.value=${json(user)};document.querySelector('#password').value=${json(secret)};document.querySelector('form').requestSubmit();`);
const save = (browser, origin=browser.fixture.origin,user="fixture",secret=password) => moduleCall(browser,"save",["",origin,user,secret]);
async function savedFromPage(browser) {
  const id=await browser.open("/pw-plain");
  await submit(browser,id);
  await browser.loaded(id,titleOf("/pw-success"));
  const event=await prompt(browser,id);
  assert.equal(event.state,"save");assert.equal(event.origin,browser.fixture.origin);
  assert.equal(Object.hasOwn(event,"password"),false);
  assert.equal(event.passwordLength,password.length);
  await answer(browser,id,"save");
  await browser.until('return ac.engine.call("passwords.list",{profile:""}).then(r=>r.passwords.length===1);');
  return id;
}
async function focus(browser,id,selector="#password") {
  await browser.execute(id,`document.querySelector(${json(selector)}).focus();`);
  await sleep(300);
  assert.equal((await call(browser,"webKit.devPasswordFocus",{tabId:id,probe:true})).empty,true,"a scripted focus without a user gesture filled the password");
  await call(browser,"webKit.devPasswordFocus",{tabId:id});
}
async function filled(browser,id,user="fixture",secret=password) {
  await browser.until(`return ac.webviews.get(${json(id)}).evaluate(${json(`post("result",JSON.stringify(document.querySelector('#password').value === ${json(secret)} && (!document.querySelector('#username') || document.querySelector('#username').value === ${json(user)})));`)});`);
}
function cleanLogs(browser, secrets=[password,updated]) {
  for(const name of readdirSync(browser.data).filter(name=>name.endsWith(".log"))) {
    const log=readFileSync(join(browser.data,name),"utf8");
    for(const secret of secrets) assert.ok(!log.includes(secret),"password appeared in app log");
  }
}
export async function passwordNative(scratch) {
  const buffer=join(scratch,"password-buffer.o"), executable=join(scratch,"password-native");
  await run("xcrun",["clang++","-fobjc-arc","-c","packages/ardiacore/tests/webkit-password-buffer.mm","-o",buffer]);
  await run("xcrun",["swiftc","-lc++","-import-objc-header","packages/ardiacore/ios/ArdiaServices.h",buffer,
    "packages/ardiacore/ios/WebKitPasswordVault.swift","packages/ardiacore/ios/WebKitPasswordScript.swift","packages/sync/ios/Core/SyncKeyStore.swift","packages/ardiacore/tests/webkit-passwords.test.swift","-o",executable]);
  return (await run(executable,[join(scratch,"password-unit")],{env:{ARDIA_BACKGROUND:"1"}})).text.trim();
}
export const passwordRows = {
  "pw-save": async ({browser})=>{
    const id=await savedFromPage(browser);
    assert.equal((await list(browser))[0].username,"fixture");
    await browser.evaluate('ac.openSettings("passwords");return true;');
    await browser.until('return ac.settingsNav.getState().pane==="passwords";');
    await browser.evaluate('const button=globalThis.acPerf.findFibers("Button").find(f=>f.memoizedProps.title==="Unlock");if(button)button.memoizedProps.onPress();return true;');
    await browser.until('return globalThis.acPerf.findFibers("Text").some(f=>f.memoizedProps.children==="fixture");');
    assert.equal((await call(browser,"passwords.unlock")).unlocked,true);
    assert.equal(await browser.page(id,"document.querySelector('#result').textContent"),"Signed in");
    const twoStep=await browser.open(browser.fixture.origin.replace("127.0.0.1","localhost")+"/pw-username");
    await browser.execute(twoStep,"document.querySelector('#username').value='step-user';document.querySelector('form').requestSubmit();");
    await browser.loaded(twoStep,titleOf("/pw-password"));await submit(browser,twoStep);
    await browser.loaded(twoStep,titleOf("/pw-success"));assert.equal((await prompt(browser,twoStep)).username,"step-user");
    await answer(browser,twoStep,"save");assert.equal((await list(browser)).length,2);
    cleanLogs(browser);
    return "plain and two-step page-world form submit; unchanged save event accepted; Settings list contains login; fixture authenticated; logs contain no password";
  },
  "pw-fill": async ({browser,fixture})=>{
    await save(browser);await browser.restart();
    const id=await browser.open("/pw-plain");
    await browser.execute(id,"document.body.dataset.inputs=0;document.addEventListener('input',()=>document.body.dataset.inputs=Number(document.body.dataset.inputs)+1);");
    await focus(browser,id);await filled(browser,id);
    assert.ok(await browser.page(id,"Number(document.body.dataset.inputs)>=2"));
    await browser.execute(id,"document.querySelector('form').requestSubmit()");await browser.loaded(id,titleOf("/pw-success"));
    assert.equal(await browser.page(id,"document.querySelector('#result').textContent"),"Signed in");
    assert.ok(fixture.passwordLogins.includes("fixture"));
    assert.equal(await browser.sql("SELECT last_used>0 FROM passwords;"),"1");
    const dynamic=await browser.open("/pw-dynamic");await focus(browser,dynamic);await filled(browser,dynamic);
    const twoStep=await browser.open("/pw-username");
    await browser.execute(twoStep,"document.querySelector('#username').value='fixture';document.querySelector('form').requestSubmit();");
    await browser.loaded(twoStep,titleOf("/pw-password"));await focus(browser,twoStep);await filled(browser,twoStep);
    const same=await browser.open("/pw-same-frame");
    await browser.execute(same,"document.querySelector('iframe').contentDocument.querySelector('#password').focus()");
    await sleep(300);
    assert.equal((await call(browser,"webKit.devPasswordFocus",{tabId:same,subframe:true,probe:true})).empty,true,"a scripted focus without a user gesture filled the password");
    await call(browser,"webKit.devPasswordFocus",{tabId:same,subframe:true});
    await browser.until(`return ac.webviews.get(${json(same)}).evaluate(${json(`post("result",JSON.stringify(document.querySelector('iframe').contentDocument.querySelector('#password').value===${json(password)}));`)});`);
    cleanLogs(browser);
    return "new process fills and authenticates; last-used updated; dynamic form, two-step form and same-origin iframe fill";
  },
  "pw-update": async ({browser})=>{
    await save(browser);const id=await browser.open("/pw-plain");await submit(browser,id,updated);
    assert.equal((await prompt(browser,id)).state,"update");await answer(browser,id,"update");
    const next=await browser.open("/pw-plain");await focus(browser,next);await filled(browser,next,"fixture",updated);
    const result=await moduleCall(browser,"update",["",browser.fixture.origin,"fixture","renamed",null]);assert.equal(result.ok,true);
    assert.equal((await list(browser))[0].username,"renamed");
    await call(browser,"passwords.remove",{origin:browser.fixture.origin,username:"renamed"});assert.equal((await list(browser)).length,0);
    await save(browser);await save(browser,browser.fixture.origin,"second","fixture-second-pass");
    const selection=await browser.open("/pw-plain");await submit(browser,selection,updated);await browser.loaded(selection,titleOf("/pw-success"));await prompt(browser,selection);
    await browser.evaluate(`return ac.webviews.get(${json(selection)}).resolvePasswordPrompt("update",{username:"second"});`);
    assert.equal(await browser.evaluate(`return ac.engine.call("passwords.reveal",{profile:"",origin:${json(browser.fixture.origin)},username:"second"}).then(r=>r.password===${json(updated)});`),true);
    assert.equal(await browser.evaluate(`return ac.engine.call("passwords.reveal",{profile:"",origin:${json(browser.fixture.origin)},username:"fixture"}).then(r=>r.password===${json(password)});`),true);
    cleanLogs(browser);return "changed submit offers update; accepted password fills; native Settings rename and delete work";
  },
  "pw-never": async ({browser})=>{
    const id=await browser.open("/pw-plain");await submit(browser,id);await prompt(browser,id);await answer(browser,id,"never");
    assert.deepEqual((await call(browser,"passwords.neverSaveOrigins")).origins,[browser.fixture.origin]);
    await browser.restart();const next=await browser.open("/pw-plain");await submit(browser,next);await browser.loaded(next,titleOf("/pw-success"));await sleep(300);
    assert.equal(await browser.evaluate(`return ac.pageState.getState().pages[${json(next)}]?.passwordPrompt??null;`),null);
    await call(browser,"passwords.allowSaving",{origin:browser.fixture.origin});assert.deepEqual((await call(browser,"passwords.neverSaveOrigins")).origins,[]);
    await call(browser,"passwords.setAutofillEnabled",{enabled:false});await save(browser);
    await browser.restart();assert.equal(await call(browser,"passwords.autofillEnabled"),false);
    const disabled=await browser.open("/pw-plain");await focus(browser,disabled);await sleep(300);assert.equal(await browser.page(disabled,"document.querySelector('#password').value"),"");
    return "Never persists and suppresses prompts; allow-saving removes exception; offer/autofill toggle persists and prevents fill";
  },
  "pw-two-accounts": async ({browser})=>{
    await save(browser);await save(browser,browser.fixture.origin,"second","fixture-second-pass");
    const id=await browser.open("/pw-plain");await focus(browser,id);await sleep(300);assert.equal(await browser.page(id,"document.querySelector('#password').value"),"");
    writeFileSync(join(browser.data,"password-menu.json.pick"),"second");
    await call(browser,"webKit.devPasswordFocus",{tabId:id});
    await filled(browser,id,"second","fixture-second-pass");
    const items=JSON.parse(readFileSync(join(browser.data,"password-menu.json"),"utf8"));assert.deepEqual(items.map(item=>item.title),["fixture","second"]);
    cleanLogs(browser,[password,"fixture-second-pass"]);return "two accounts stay empty until choice; logged NSMenu lists both; native action fills only selected account";
  },
  "pw-origin": async ({browser,fixture})=>{
    await save(browser,fixture.origin.replace("http:","https:"));
    const downgrade=await browser.open("/pw-plain");await focus(browser,downgrade);await sleep(250);assert.equal(await browser.page(downgrade,"document.querySelector('#password').value"),"");
    await save(browser);const other=await browser.open(fixture.origin.replace("127.0.0.1","localhost")+"/pw-plain");await focus(browser,other);await sleep(250);assert.equal(await browser.page(other,"document.querySelector('#password').value"),"");
    const cross=await browser.open("/pw-cross-frame");
    const frame=await call(browser,"webKit.devPasswordFocus",{tabId:cross,subframe:true});assert.equal(frame.eligible,false);await sleep(250);
    assert.equal(existsSync(join(browser.data,"password-menu.json")),false);
    assert.equal((await call(browser,"webKit.devPasswordFocus",{tabId:cross,subframe:true,probe:true})).empty,true);
    for(const path of ["/pw-signup","/pw-hidden"]) {const id=await browser.open(path);await focus(browser,id);await sleep(200);assert.equal(await browser.page(id,"document.querySelector('#password').value"),"");}
    const hostile=await browser.open("/pw-hostile");await sleep(200);
    assert.deepEqual(await browser.page(hostile,"JSON.parse(document.body.dataset.handlers)"),[]);
    assert.equal(await browser.page(hostile,"document.body.dataset.isolatedApi"),"undefined");
    cleanLogs(browser);return "https login withheld on http; localhost differs from 127.0.0.1; cross-origin frame, signup and hidden fields receive nothing; hostile page has no handler or isolated API";
  },
  "pw-private": async ({browser,fixture})=>{
    await save(browser);const before=await browser.sql("SELECT hex(encrypted)||':'||last_used FROM passwords;");
    const window=await browser.evaluate(`return ac.store.getState().createWindow({kind:"private",url:${json(fixture.origin+"/pw-plain")}});`);
    const tab=await browser.until(`return Object.values(ac.store.getState().tabs).find(t=>t.windowId===${json(window)}&&t.title===${json(titleOf("/pw-plain"))});`);
    await browser.loaded(tab.id);await focus(browser,tab.id);await filled(browser,tab.id);
    await submit(browser,tab.id,updated);await browser.loaded(tab.id,titleOf("/pw-success"));await sleep(200);
    assert.equal(await browser.evaluate(`return ac.pageState.getState().pages[${json(tab.id)}]?.passwordPrompt??null;`),null);
    await assert.rejects(moduleCall(browser,"save",["incognito:test",fixture.origin,"private",password]));
    const never=await call(browser,"passwords.neverSaveOrigins",{profile:"incognito:test"});assert.deepEqual(never.origins,[]);
    assert.equal(await browser.sql("SELECT hex(encrypted)||':'||last_used FROM passwords;"),before);
    return "private frame reads base login and fills; changed submit has no prompt; direct save rejected; base ciphertext/last-used and never list unchanged";
  },
  "pw-export": async ({browser})=>{
    await save(browser);const path=join(browser.data,"chosen-passwords.csv");
    assert.equal((await call(browser,"webKit.devPasswordExport",{path})).status,"succeeded");assert.equal(statSync(path).mode&0o777,0o600);
    assert.ok(readFileSync(path,"utf8").startsWith("name,url,username,password\r\n"));
    const imported=await browser.evaluate(`return globalThis.expo.modules.ArdiaImport.importPasswordsCSV(${json(path)}).then(JSON.parse).then(rows=>rows.length===1&&rows[0].username==="fixture"&&rows[0].password===${json(password)});`);assert.equal(imported,true);
    assert.equal((await call(browser,"passwords.export")).status,"cancelled");
    browser.options.reauth="denied";await browser.restart();
    const denied=join(browser.data,"denied.csv");assert.equal((await call(browser,"webKit.devPasswordExport",{path:denied})).status,"reauthFailed");assert.equal(existsSync(denied),false);
    assert.equal((await call(browser,"passwords.reveal",{origin:browser.fixture.origin,username:"fixture"})).password,null);
    cleanLogs(browser);return "caller-chosen CSV parses through importer; mode 0600; no implicit background path; denied test unlock blocks export/reveal without dialog";
  },
  "pw-relaunch": async ({browser})=>{
    await savedFromPage(browser);const before=await list(browser);await browser.restart();assert.deepEqual(await list(browser),before);
    const id=await browser.open("/pw-plain");await focus(browser,id);await filled(browser,id);
    const isolated=await call(browser,"passwords.list",{profile:"other"});assert.deepEqual(isolated.passwords,[]);
    cleanLogs(browser);return "metadata identical after relaunch; persisted key decrypts login; other profile empty";
  },
  "pw-at-rest": async ({browser})=>{
    await savedFromPage(browser);
    const bridge=(name,values,profile="")=>call(browser,"webKit.devPasswordBridge",{name,json:values,profile});
    const added=await bridge("ac_passwords_add",json({origin:browser.fixture.origin,username:"hex",passwordHex:Buffer.from("fixture-hex-secret").toString("hex")}));
    assert.equal(added.wiped,true);assert.equal(added.result.ok,true);
    for(const malformed of ["[]","null","bad",json({origin:browser.fixture.origin,username:"bad",passwordHex:"ff"})," ".repeat(65537)]) {
      const refused=await bridge("ac_passwords_add",malformed);assert.equal(refused.wiped,true);assert.ok(refused.result.error);
    }
    const privateWrite=await bridge("ac_passwords_add",json({origin:browser.fixture.origin,username:"private",passwordHex:"61"}),"incognito:test");
    assert.equal(privateWrite.wiped,true);assert.ok(privateWrite.result.error);
    assert.match((await call(browser,"webKit.devPasswordBridge",{read:true})).error,/unsupported/);
    await assert.rejects(browser.evaluate('return globalThis.expo.modules.ArdiaSync.savePassword("","https://fixture.example","fixture","fixture-sealed",false);'),/unsupported/i);
    for(const name of readdirSync(join(browser.data,"WebKit/Stores"))) for(const secret of [password,"fixture-hex-secret"]) {
      const result=await run("grep",["-a","-l","-F",secret,join(browser.data,"WebKit/Stores",name)],{allowFailure:true});assert.equal(result.status,1,"plaintext found in SQLite or sidecar");
    }
    assert.equal(await browser.sql("SELECT MIN(typeof(encrypted)='blob' AND length(encrypted)>28) FROM passwords;"),"1");
    cleanLogs(browser,[password,"fixture-hex-secret"]);return "secret bridge hex/invalid/private/oversize inputs wiped; sync read/write explicitly unsupported; grep -a -l -F fixture password: exit 1 for SQLite/WAL/SHM; encrypted BLOB stored; app logs contain no password";
  },
};
