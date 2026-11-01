const {test} = require('node:test');
const assert = require('node:assert/strict');
const source = require('node:fs').readFileSync('lib/api/tiktok_client.dart', 'utf8');
const body = source.slice(source.indexOf('Future<DeleteResult> _commitWebAction')).match(/const functionBody = r'''([\s\S]*?)''';/)[1];
const AsyncFunction = Object.getPrototypeOf(async function(){}).constructor;
for (const path of ['/api/commit/item/digg/', '/api/commit/follow/user/']) {
  for (const [raw, status, code, token] of [
    ['{"status_code":0}',200,0,true], ['{"status_code":"0"}',200,0,true],
    ['<html>',200,-2,true], ['',200,-2,true], ['{}',403,403,true],
    ['{"status_code":10402}',200,10402,true], ['{}',200,-2,true], ['{}',200,10402,false]
  ]) test(`${path} ${raw} HTTP ${status} token ${token}`, async () => {
    let calls = 0;
    const params = path.includes('digg') ? {aweme_id:'123',type:'0'} : {user_id:'456',sec_user_id:'target',type:'0'};
    const fetch = async (request, options) => {
      calls++;
      const url = new URL(request);
      assert.equal(url.pathname,path);
      for (const [k,v] of Object.entries(params)) assert.equal(url.searchParams.get(k),v);
      assert.equal(url.searchParams.get('device_id'),'device');
      assert.equal(options.body,'');
      assert.equal(options.headers['tt-csrf-token'],'web-token');
      return {ok:status===200,status,url:request,headers:{get:()=>null},text:async()=>raw};
    };
    const app = {csrfToken:token?'web-token':'',wid:'device'};
    const document = {getElementById:()=>({textContent:JSON.stringify({__DEFAULT_SCOPE__:{'webapp.app-context':app}})})};
    const run = new AsyncFunction('window','document','location','navigator','path','params','aid',body);
    const result = JSON.parse(await run({fetch,__UNIVERSAL_DATA_FOR_REHYDRATION__:{nodeType:1}},document,
      {origin:'https://www.tiktok.com'},{language:'vi-VN',platform:'iPhone',userAgent:'browser'},path,params,1988));
    assert.equal(result.status_code,code);
    assert.equal(result.success,code===0);
    assert.equal(calls,token?1:0);
    assert.ok(!result.raw.includes('web-token'));
  });
}
