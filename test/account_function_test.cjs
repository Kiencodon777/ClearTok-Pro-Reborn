const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const {transformSync}=require('esbuild');

test('account handler rejects unverified tokens, maps rate limit to 429, and enforces byte limit',async()=>{
  let handler,calls=0,verified=false,rpcError=null;
  const source=fs.readFileSync('supabase/functions/account/index.ts','utf8')
    .replace(/^import .*;\r?\n/,'');
  const client={auth:{getUser:async()=>({data:{user:verified?{id:'test-user'}:null},error:null})},
    rpc:async()=>{calls++;return {data:rpcError?null:{ok:true},error:rpcError};}};
  vm.runInNewContext(transformSync(source,{loader:'ts'}).code,{
    Deno:{serve:f=>handler=f,env:{get:()=> 'test-only'}},
    createClient:()=>client,Response,Request,JSON,TextEncoder,
  });
  const request=(token,payload={})=>new Request('https://test.invalid/account',{
    method:'POST',headers:token?{Authorization:'Bearer '+token}:{},
    body:JSON.stringify({action:'current',payload}),
  });
  assert.equal((await handler(request())).status,401);
  assert.equal((await handler(request('invalid'))).status,401);
  assert.equal(calls,0);
  verified=true;
  assert.equal((await handler(request('test-session'))).status,200);
  assert.equal(calls,1);

  // H2: Rate limit exceeded maps to 429 instead of 403
  rpcError={message:'Rate limit exceeded',code:'42501'};
  const rateRes=await handler(request('test-session'));
  assert.equal(rateRes.status,429);
  assert.deepEqual(await rateRes.json(),{error:'Rate limit exceeded'});

  // Other RPC errors still map to 403
  rpcError={message:'Account unavailable',code:'42501'};
  const denyRes=await handler(request('test-session'));
  assert.equal(denyRes.status,403);
  assert.deepEqual(await denyRes.json(),{error:'Request denied'});
  rpcError=null;

  // Multi-byte UTF-8 body exceeding 4096 bytes returns 413 even when char length < 4096
  const multibyte='আ'.repeat(1500); // 1500 chars = 4500 UTF-8 bytes
  assert.equal((await handler(request('test-session',{pad:multibyte}))).status,413);

  assert.match(fs.readFileSync('supabase/config.toml','utf8'),/verify_jwt = false/);
});
