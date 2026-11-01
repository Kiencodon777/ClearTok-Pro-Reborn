const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const load=name=>import(pathToFileURL(path.resolve('build/cleartok-web/'+name)).href);
test('pagination handles zero aliases and honors end flag',async()=>{
  const {nextCursor,morePages,mergeItems}=await load('core.mjs');
  assert.equal(nextCursor({cursor:0,minCursor:'999'},0),999);
  assert.equal(nextCursor({cursor:999,maxCursor:2000},999),2000);
  assert.equal(morePages({hasMore:false},30,true),false);
  assert.throws(()=>morePages({hasMore:true},30,false));
  for(const limit of [50,100,200,0]){
    let items=[];
    for(let page=0;page<8;page++)items=mergeItems(items,Array.from({length:30},(_,i)=>({id:String(page*30+i)})),limit);
    assert.equal(items.length,limit||240);
  }
  assert.equal(mergeItems([{id:'1'}],[{id:'1'},{id:'2'}]).length,2);
});
test('filters, analytics, and CSV escape data and spreadsheet formulas',async()=>{
  const {filterItems,analytics,csv}=await load('core.mjs');
  const items=[{id:'1',author:'alice',title:'hello',time:10},{id:'2',author:'bob',title:'=SUM(1)',time:20}];
  assert.equal(filterItems(items,{query:'ALICE'})[0].id,'1');
  assert.equal(filterItems(items,{sort:'old'})[0].id,'1');
  assert.equal(filterItems(items,{sort:'new'})[0].id,'2');
  assert.equal(analytics(items).creators,2);
  assert.match(csv(items),/"'=SUM\(1\)"/);
});
test('stop interrupts waits even when paused',async()=>{
  const {TaskControl}=await load('core.mjs');const ctrl=new TaskControl();ctrl.paused=true;
  const wait=ctrl.wait(10000);setTimeout(()=>ctrl.stop(),5);assert.equal(await wait,false);
});
async function execute(command,input,expected='owner',response={status_code:0,itemList:[],hasMore:false}){
  const {pageExecute}=await load('page-api.mjs');let captured;
  const app={user:{id:'123',secUid:'owner',uniqueId:'tester'},csrfToken:'test-token',wid:'device'};
  const context=vm.createContext({location:{origin:'https://www.tiktok.com'},
    window:{__UNIVERSAL_DATA_FOR_REHYDRATION__:{__DEFAULT_SCOPE__:{'webapp.app-context':app}}},
    document:{getElementById:()=>null},navigator:{language:'en',platform:'test',userAgent:'browser'},
    URL,AbortController,setTimeout,clearTimeout,command,input,expected});
  context.fetch=async(url,options)=>{captured={url:String(url),options};return {ok:true,status:200,url:String(url),headers:{get:()=>null},text:async()=>JSON.stringify(response)};};
  context.window.fetch=context.fetch;
  const value=await vm.runInContext(`(${pageExecute.toString()})(command,input,expected)`,context);
  return {value,captured};
}
test('page function serializes standalone and never exports tokens in profile',async()=>{
  const {value,captured}=await execute('profile',{});
  assert.equal(value.secUid,'owner');assert.equal(captured,undefined);
  assert.ok(!JSON.stringify(value).includes('test-token'));
});
test('page refuses mutations for a different account or malformed IDs',async()=>{
  await assert.rejects(execute('mutate',{mode:'unlike',item:{id:'12'}},'other'),/Tài khoản/);
  await assert.rejects(execute('mutate',{mode:'unlike',item:{id:'bad&url=evil'}}),/ID/);
  await assert.rejects(execute('scan',{mode:'evil',cursor:0}),/Chế độ/);
});
test('following scan uses next cursor and normalizes a real response shape',async()=>{
  const {value,captured}=await execute('scan',{mode:'unfollow',cursor:456},'owner',{
    status_code:0,userList:[{user:{id:'9',secUid:'target',uniqueId:'creator',nickname:'Name'}}],minCursor:789,hasMore:true});
  const url=new URL(captured.url);assert.equal(url.pathname,'/api/user/list/');
  assert.equal(url.searchParams.get('maxCursor'),'456');assert.equal(value.items[0].secUid,'target');
  assert.equal(value.minCursor,789);
});
test('web unlike uses exact mobile POST with query and no body',async()=>{
  const {value,captured}=await execute('mutate',{mode:'unlike',item:{id:'456',author:'creator'}},'owner',{status_code:0});
  const url=new URL(captured.url);assert.equal(url.searchParams.get('aweme_id'),'456');
  assert.equal(captured.options.method,'POST');assert.equal(captured.options.body,'');
  assert.equal(value.success,true);assert.ok(!value.raw.includes('test-token'));
});
test('manifest grants only TikTok hosts and uses strict extension CSP',()=>{
  const m=JSON.parse(fs.readFileSync('build/cleartok-web/manifest.json','utf8'));
  assert.deepEqual(m.host_permissions,['https://www.tiktok.com/*']);
  assert.ok(!m.permissions.includes('cookies'));
  assert.ok(!m.content_security_policy.extension_pages.includes('unsafe-eval'));
});
