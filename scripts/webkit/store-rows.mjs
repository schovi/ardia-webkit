import assert from 'node:assert/strict';
import {existsSync,readFileSync,rmSync,readdirSync} from 'node:fs';
import {join} from 'node:path';
import {checkNetworkConnection} from './rows.mjs';

const id='ddkjiahejlhfcafbddmgiahcphecmpfh';
const url=`https://chromewebstore.google.com/detail/ublock-origin-lite/${id}?hl=en`;
const call=(b,name,args={})=>b.evaluate(`return ac.engine.call(${JSON.stringify(name)},${JSON.stringify(args)});`);
const isolated=(b,tabId,script)=>call(b,'webKit.devExtensionStore',{tabId,script});
async function openStore(browser) {
  const tab = await browser.open(url);
  const location = await isolated(browser,tab,'return location.href;');
  if (new URL(location).hostname === 'consent.google.com') {
    assert.equal(await isolated(browser,tab,`const reject=document.querySelector('button[aria-label="Reject all"]');if(!reject)return false;reject.click();return true;`),true,'Google consent Reject all button missing');
    await browser.until(`return ac.engine.call('webKit.devExtensionStore',{tabId:${JSON.stringify(tab)},script:"return location.origin==='https://chromewebstore.google.com' && document.readyState==='complete';"});`,30000);
  }
  return tab;
}
const button=`[...document.querySelectorAll('button')].find(b=>/^(Add to Ardia|Added)$/.test(b.textContent.trim()))`;
export const storeRows={
  'ext-store':async({browser})=>{
    await checkNetworkConnection('https://chromewebstore.google.com/');
    await browser.evaluate(`globalThis.storeFailures=[];ac.engine.on("extensions.installFailed",e=>globalThis.storeFailures.push(e));return true;`);
    let tab=await openStore(browser);
    await browser.until(`return ac.engine.call('webKit.devExtensionStore',{tabId:${JSON.stringify(tab)},script:${JSON.stringify(`return !!(${button}) && !(${button}).disabled;`)}});`,30000);
    await browser.execute(tab,"document.documentElement.dataset.storeAttack=JSON.stringify({handler:!!window.webkit?.messageHandlers?.ardiaExtensionStore});[...document.querySelectorAll('button')].find(b=>b.textContent.trim()==='Add to Ardia')?.click();");
    assert.equal(await browser.page(tab,'JSON.parse(document.documentElement.dataset.storeAttack).handler'),false);
    await isolated(browser,tab,"window.webkit.messageHandlers.ardiaExtensionStore.postMessage('forged');return true;");
    await browser.until("return ac.engine.call('webKit.devExtensionStore',{stats:true}).then(s=>s.nonce>0);");
    const promptFile=join(browser.data,'WebKit/extension-install-prompt.json');
    assert.equal(existsSync(promptFile),false);
    assert.equal(await isolated(browser,tab,'return window.__ardiaStoreTestClick();'),true);
    for(const end=Date.now()+90000;Date.now()<end&&!existsSync(promptFile);await new Promise(r=>setTimeout(r,500))) { const failures=await browser.evaluate('return globalThis.storeFailures??[];');assert.equal(failures.length,0,JSON.stringify(failures)); }
    assert.ok(existsSync(promptFile),'store install prompt missing');
    let prompt=JSON.parse(readFileSync(promptFile));assert.equal(prompt.id,id);assert.ok(prompt.permissions.length>0);
    assert.equal((await call(browser,'extensions.list',{profile:''})).extensions.length,0);
    await call(browser,'extensions.resolveInstallPrompt',{requestId:prompt.requestId,accepted:true});
    await browser.until(`return ac.engine.call('extensions.list',{profile:''}).then(r=>r.extensions.some(e=>e.id===${JSON.stringify(id)}));`,30000);
    await browser.restart();tab=await openStore(browser);
    await browser.until(`return ac.engine.call('webKit.devExtensionStore',{tabId:${JSON.stringify(tab)},script:${JSON.stringify(`return (${button})?.textContent.trim()==='Added' && (${button}).disabled;`)}});`,30000);
    await call(browser,'extensions.uninstall',{profile:'',id});
    rmSync(promptFile,{force:true});
    await browser.execute(tab,'location.reload();');await browser.loaded(tab);
    await browser.until(`return ac.engine.call('webKit.devExtensionStore',{tabId:${JSON.stringify(tab)},script:${JSON.stringify(`return !!(${button}) && !(${button}).disabled;`)}});`);
    await isolated(browser,tab,'return window.__ardiaStoreTestClick();');
    for(const end=Date.now()+90000;Date.now()<end&&!existsSync(promptFile);await new Promise(r=>setTimeout(r,500))) { const failures=await browser.evaluate('return globalThis.storeFailures??[];');assert.equal(failures.length,0,JSON.stringify(failures)); }
    assert.ok(existsSync(promptFile));prompt=JSON.parse(readFileSync(promptFile));
    await call(browser,'extensions.resolveInstallPrompt',{requestId:prompt.requestId,accepted:false});
    await browser.until(`return ac.engine.call('webKit.devExtensionStore',{tabId:${JSON.stringify(tab)},script:${JSON.stringify(`return !!(${button}) && !(${button}).disabled;`)}});`);
    assert.equal((await call(browser,'extensions.list',{profile:''})).extensions.length,0);
    const managed=join(browser.data,'WebKit/Extensions');
    for(const end=Date.now()+10000;Date.now()<end&&readdirSync(managed).some(n=>n.startsWith('download-')||n.startsWith('staging-'));await new Promise(r=>setTimeout(r,100)));
    assert.ok(!readdirSync(managed).some(n=>n.startsWith('download-')||n.startsWith('staging-')));
    return 'real store button enabled; page world has no handler; authenticated requested id; no install before consent; accepted id survives relaunch and Added button disabled; decline leaves no extension or staging files';
  },
  'ext-store-origin':async({browser})=>{
    const tab=await browser.open('/first');
    await browser.execute(tab,`document.body.innerHTML='<button disabled>Add to Chrome</button><iframe srcdoc="<button>Add to Chrome</button>"></iframe>';document.documentElement.dataset.storeAttack=JSON.stringify({handler:!!window.webkit?.messageHandlers?.ardiaExtensionStore,hook:typeof window.__ardiaStoreTestClick});document.querySelector('button').click();`);
    assert.deepEqual(await browser.page(tab,'JSON.parse(document.documentElement.dataset.storeAttack)'),{handler:false,hook:'undefined'});
    await isolated(browser,tab,"window.webkit.messageHandlers.ardiaExtensionStore.postMessage('forged');return true;");
    await isolated(browser,tab,'return window.__ardiaStoreTestClick();');
    const stats=await browser.until("return ac.engine.call('webKit.devExtensionStore',{stats:true}).then(s=>s.main>0&&s.subframe>0?s:null);");
    assert.equal((await call(browser,'extensions.list',{profile:''})).extensions.length,0);
    assert.equal(existsSync(join(browser.data,'WebKit/extension-install-prompt.json')),false);
    return `native denied local main frame and subframe (${stats.main}/${stats.subframe}); page world has neither handler nor test hook; no install prompt or extension`;
  }
};
