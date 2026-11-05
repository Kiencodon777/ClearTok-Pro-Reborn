const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {transformSync}=require('esbuild');

test('account handler rejects unverified tokens before database calls',async()=>{
  let handler,calls=0,verified=false;
  const source=fs.readFileSync('supabase/functions/account/index.ts','utf8')
    .replace(/^import .*;\r?\n/,'');
  const client={auth:{getUser:async()=>({data:{user:verified?{id:'test-user'}:null},error:null})},
    rpc:async()=>{calls++;return {data:{ok:true},error:null};}};
  vm.runInNewContext(transformSync(source,{loader:'ts'}).code,{
    Deno:{serve:f=>handler=f,env:{get:()=> 'test-only'}},
    createClient:()=>client,Response,Request,JSON,
  });
  const request=token=>new Request('https://test.invalid/account',{
    method:'POST',headers:token?{Authorization:'Bearer '+token}:{},
    body:JSON.stringify({action:'current',payload:{}}),
  });
  assert.equal((await handler(request())).status,401);
  assert.equal((await handler(request('invalid'))).status,401);
  assert.equal(calls,0);
  verified=true;
  assert.equal((await handler(request('test-session'))).status,200);
  assert.equal(calls,1);
  assert.match(fs.readFileSync('supabase/config.toml','utf8'),/verify_jwt = false/);
});
