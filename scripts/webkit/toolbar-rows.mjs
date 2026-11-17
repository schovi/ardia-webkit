import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync,readFileSync,copyFileSync} from 'node:fs';
import {join} from 'node:path';
import {createRequire} from 'node:module';
import {BUILD} from './support.mjs';
const {PNG}=createRequire(new URL('../../packages/demo/package.json',import.meta.url))('pngjs');

export function rect(text) {
  const values=text.match(/-?\d+(?:\.\d+)?/g)?.map(Number);
  assert.equal(values?.length,4,`invalid rectangle: ${text}`);
  return values;
}
function contains(outer,inner) {
  return inner[0]>=outer[0]-.5&&inner[1]>=outer[1]-.5&&inner[0]+inner[2]<=outer[0]+outer[2]+.5&&inner[1]+inner[3]<=outer[1]+outer[3]+.5;
}
export function assertFullPage(views) {
  assert.ok(views.length>1);
  let page=rect(views[0].bounds);
  assert.ok(page[2]>0&&page[3]>100);
  for(let i=0;i<views.length;i++) {
    const view=views[i],bounds=rect(view.bounds);
    assert.ok(contains(rect(view.visibleRect),page),`${view.class} visibleRect clips page: ${JSON.stringify(view)}`);
    if(view.layer?.mask) assert.equal(view.layer.mask,'nil',`${view.class} has an unexamined layer mask`);
    if(view.layer?.masksToBounds) assert.ok(contains(bounds,page),`${view.class} layer clips page`);
    if(i+1<views.length) {
      const frame=rect(view.frame),parent=views[i+1];
      const x=frame[0]+(page[0]-bounds[0])*frame[2]/bounds[2];
      const y=frame[1]+(view.flipped===parent.flipped ? page[1]-bounds[1] : bounds[3]-(page[1]-bounds[1])-page[3])*frame[3]/bounds[3];
      page=[x,y,page[2]*frame[2]/bounds[2],page[3]*frame[3]/bounds[3]];
    }
  }
}

export async function toolbarCollapse({browser}) {
  const directory=join(BUILD,'toolbar-evidence');mkdirSync(directory,{recursive:true});
  const call=(name,args={})=>browser.evaluate(`return ac.engine.call(${JSON.stringify(name)},${JSON.stringify(args)});`);
  const id=await browser.open();
  const geometry=tabId=>call('webKit.devPageGeometry',{tabId});
  const tall=async tabId=>{await browser.execute(tabId,'document.body.style.height="8000px";document.body.style.background="linear-gradient(red,blue)"');await browser.page(tabId,'document.body.scrollHeight');};
  const gesture=async(tabId,delta=-60,cache=false)=>{
    const samples=await call('webKit.devPageGeometry',{tabId,record:'',nativeScroll:true,delta,cache});
    assertFullPage(samples.find(s=>s.at===2).views);
    const events=samples.find(s=>s.events).events;
    for(const phase of [1,4,8]) {assert.ok(events.some(e=>e.phase===phase));assert.ok(events.some(e=>e.momentum===phase));}
    assert.ok(events.every(e=>e.hit.includes('WebKit')));
    return samples;
  };
  await tall(id);
  const before=await geometry(id),height=rect(before[0].bounds)[3];
  await browser.evaluate("ac.reactNative.DeviceEventEmitter.emit('reduceMotionChanged',false);return true;");
  const down=await gesture(id,-60,true);
  const collapsed=down.find(s=>s.at===2).views;
  assert.ok(rect(collapsed[0].bounds)[3]>height);
  assert.ok(await browser.page(id,'scrollY>0'));
  writeFileSync(join(directory,'toolbar-collapse.json'),JSON.stringify(down,null,2));
  const window=(await call('webKit.devPageState',{tabId:id})).window;
  await call('windows.dev',{window,action:'hardwareKey:5|1703936'});
  await browser.until(`return ac.engine.call('webKit.devPageState',{tabId:${JSON.stringify(id)}}).then(s=>s.key);`);
  const diagnostic=JSON.parse(readFileSync(join(browser.data,'WebKit/webkit-geometry.json'),'utf8'));
  assert.equal(diagnostic.toolbar.mode,'collapsed');assert.equal(diagnostic.toolbar.reduce,false);assert.ok(diagnostic.macOS&&diagnostic.webKit&&diagnostic.backingScale);
  assert.ok(!JSON.stringify(diagnostic).includes(browser.fixture.origin));
  copyFileSync(join(browser.data,'WebKit/webkit-geometry.json'),join(directory,'owner-diagnostic.json'));
  for(const time of [0,100,400,1000,2000]) {
    const name=time ? `page-cache-${time}.png` : 'page-cache.png';
    const picture=PNG.sync.read(readFileSync(join(browser.data,name)));
    copyFileSync(join(browser.data,name),join(directory,`toolbar-collapse-${time}.png`));
    for(const part of [.1,.5,.9]) {const offset=(Math.floor(picture.height*part)*picture.width+Math.floor(picture.width*.8))*4;assert.ok(picture.data[offset]>picture.data[offset+1]*2&&picture.data[offset+1]<80,`page cache at ${time}ms/${part}: ${[...picture.data.subarray(offset,offset+4)]}`);}
  }
  await gesture(id,60);
  assert.equal(rect((await geometry(id))[0].bounds)[3],height);
  assert.equal(await browser.evaluate(`return !!ac.toolbarAutoHide.useToolbarAutoHide.getState().scrolledDown[${JSON.stringify(id)}];`),false);
  await browser.evaluate("ac.reactNative.DeviceEventEmitter.emit('reduceMotionChanged',true);return true;");
  writeFileSync(join(directory,'toolbar-collapse-reduced.json'),JSON.stringify(await gesture(id),null,2));
  await call('windows.dev',{window,action:'hardwareKey:5|1703936'});await browser.page(id,'innerHeight');
  assert.equal(JSON.parse(readFileSync(join(browser.data,'WebKit/webkit-geometry.json'),'utf8')).toolbar.reduce,true);
  await gesture(id,60);assert.equal(rect((await geometry(id))[0].bounds)[3],height);
  await browser.evaluate("ac.reactNative.DeviceEventEmitter.emit('reduceMotionChanged',false);return true;");
  await gesture(id);
  await browser.evaluate(`const root=globalThis.acPerf.findFibers('AutoHideToolbar').find(f=>f.memoizedProps.tabId===${JSON.stringify(id)});let picked=false;function walk(f){if(!f||picked)return;if(f.memoizedProps?.tooltip==='Show Toolbar'&&f.memoizedProps.onMouseEnter){f.memoizedProps.onMouseEnter();picked=true;return;}walk(f.child);walk(f.sibling)}walk(root?.child);if(!picked)throw Error('hover handler missing');return true;`);
  await browser.until(`return globalThis.acPerf.findFibers('AutoHideToolbar').some(f=>f.memoizedProps.tabId===${JSON.stringify(id)}&&f.memoizedProps.mode==='peek');`);
  assertFullPage(await geometry(id));
  await gesture(id,60);
  await browser.evaluate('ac.store.getState().updateSettings({bookmarksBar:"always",showBookmarks:true});return true;');
  await browser.until(`return ac.webviews.get(${JSON.stringify(id)}).evaluate('post("result",JSON.stringify(innerHeight<${height}));');`);
  const bookmarksHeight=await browser.page(id,'innerHeight');
  await gesture(id);assert.ok(await browser.page(id,`innerHeight>${bookmarksHeight}+21`));assertFullPage(await geometry(id));
  await call('windows.dev',{window,action:'resize:1100,740'});await gesture(id);assertFullPage(await geometry(id));
  await gesture(id,60);
  await browser.evaluate(`return ac.webviews.get(${JSON.stringify(id)}).showDevTools();`);
  await call('webKit.devInspector',{tabId:id,action:'attach'});
  await browser.until(`return ac.engine.call('webKit.devInspector',{tabId:${JSON.stringify(id)}}).then(s=>s.visible&&s.frontend?.visible);`);
  await gesture(id);
  await call('windows.dev',{window,action:'hardwareKey:5|1703936'});
  await browser.page(id,'innerHeight');
  const dock=JSON.parse(readFileSync(join(browser.data,'WebKit/webkit-geometry.json'),'utf8'));
  const page=rect(dock.views[0].frame),parent=rect(dock.views[1].bounds),inspector=rect(dock.inspector[0].frame);
  assert.equal(dock.views[1].flipped,false);
  assert.ok(Math.abs(page[1]+page[3]-parent[3])<1);assert.ok(Math.abs(inspector[1])<1);assert.ok(Math.abs(page[1]-inspector[3])<1);
  writeFileSync(join(directory,'docked.json'),JSON.stringify(dock,null,2));
  await browser.snapshot('docked.png',window);copyFileSync(join(browser.data,'docked.png'),join(directory,'docked.png'));
  await call('webKit.devInspector',{tabId:id,action:'close'});
  const second=await browser.open('/split-two');await tall(second);
  await browser.evaluate(`ac.store.getState().createSplit([${JSON.stringify(id)},${JSON.stringify(second)}]);return true;`);
  await browser.until(`return ac.webviews.has(${JSON.stringify(id)})&&ac.webviews.has(${JSON.stringify(second)});`);
  for(const tab of [id,second]) {await gesture(tab,60);await gesture(tab);assert.ok(await browser.page(tab,'scrollY>0'));}
  return 'native gesture + momentum phases routed to WebKit; full bounds visible and timed AppKit caches painted; both motion paths and up/top restored; rendered hover handler, bookmarks, resize, two split panes passed; docked inspector below page; owner shortcut wrote geometry only; reported screen strip not reproduced';
}
