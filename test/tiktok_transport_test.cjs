const {test} = require('node:test');
const assert = require('node:assert/strict');
const source = require('node:fs').readFileSync('lib/api/tiktok_mutation_transport.dart','utf8');
const bridge = source.match(/mainWorldBridgeJs = r'''([\s\S]*?)''';/)[1];
const body = source.match(/const functionBody = r'''([\s\S]*?)''';/)[1];
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
async function request({raw='{"status_code":0}',status=200,liked=false,same=true,spa=false,timeout=false,path='/api/commit/item/digg/'}={}) {
  let posts=0;
  const app={csrfToken:'secret',wid:'device',user:{id:'account'}};
  const nodes=[];
  function node(){return {attrs:{},style:{},setAttribute(k,v){this.attrs[k]=String(v);},
    getAttribute(k){return this.attrs[k];},remove(){nodes.splice(nodes.indexOf(this),1);}};}
  const bus=node();bus.appendChild=n=>nodes.push(n);
  bus.querySelectorAll=()=>nodes.filter(n=>n.getAttribute('data-state')==='pending');
  const listeners={};
  const document={cookie:'',documentElement:node(),createElement:node,
    getElementById:id=>id==='__lapin_mw_bus'?bus:{textContent:JSON.stringify({__DEFAULT_SCOPE__:{'webapp.app-context':app}})},
    addEventListener:(k,fn)=>listeners[k]=fn,
    dispatchEvent:e=>listeners[e.type]?.()};
  const location={origin:'https://www.tiktok.com'};
  const window={fetch:async(url,opts={})=>{
    if(opts.method==='POST') throw Error('isolated-world POST forbidden');
    if(opts.method==='HEAD'||opts.method==='GET')return {headers:{get:()=>null}};
    return {ok:true,status:200,redirected:false,text:async()=>'<html>',json:async()=>({itemInfo:{itemStruct:{id:'123',digged:liked}}})};
  }};
  class XHR {
    open(method,url){this.method=method;this.responseURL=url;}
    setRequestHeader(){}
    getResponseHeader(){return '';}
    send(){posts++;this.status=status;this.responseText=raw;timeout?this.ontimeout():this.onload();}
  }
  class Observer {observe(){}}
  new Function('window','document','location','XMLHttpRequest','MutationObserver',bridge)(window,document,location,XHR,Observer);
  class Parser {parseFromString(){return {getElementById:()=>spa?null:{textContent:JSON.stringify({__DEFAULT_SCOPE__:{
    'webapp.app-context':{user:{id:same?'account':'other'}},
    'webapp.video-detail':{itemInfo:{itemStruct:{id:'123',digged:liked}}}}})}};}}
  const result=JSON.parse(await new AsyncFunction('window','document','location','navigator','path','params','aid','DOMParser',body)(
    window,document,location,{language:'vi',platform:'iPhone',userAgent:'test'},path,
    {aweme_id:'123',type:'0',_author:'creator'},1988,Parser));
  assert.equal(posts,1);
  assert.ok(!result.raw.includes('secret'));
  assert.equal(nodes.length,0);
  return result;
}
for(const raw of ['{"status_code":0}','{"status_code":"0"}']) test('structured success '+raw,async()=>assert.equal((await request({raw})).success,true));
for(const code of [10402,3002226,429])test('challenge '+code,async()=>assert.equal((await request({raw:JSON.stringify({status_code:code})})).status_code,code));
for(const same of [true,false])for(const liked of [true,false])test('readback '+same+' '+liked,async()=>assert.equal((await request({raw:'',same,liked})).success,same&&!liked));
for(const liked of [true,false])test('SPA '+liked,async()=>assert.equal((await request({raw:'',spa:true,liked})).success,!liked));
test('unfollow empty is unverified',async()=>assert.equal((await request({raw:'',path:'/api/commit/follow/user/'})).status_code,-2));
test('timeout is unverified',async()=>assert.equal((await request({timeout:true})).success,false));
test('HTML is unverified',async()=>assert.equal((await request({raw:'<html>challenge</html>'})).success,false));
test('HTTP 429 stops',async()=>assert.equal((await request({status:429,raw:''})).status_code,429));


for(const status of [401,403,500])test('HTTP rejection '+status,async()=>assert.equal((await request({status,raw:''})).success,false));
test('repost is sent exactly once',async()=>assert.equal((await request({path:'/tiktok/v1/upvote/delete'})).success,true));
test('malformed JSON stays unverified',async()=>assert.equal((await request({raw:'{'})).success,false));

