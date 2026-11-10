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
  const request=(token,payload={},action='current',admin=false)=>new Request('https://test.invalid/account',{
    method:'POST',headers:token?{Authorization:'Bearer '+token}:{},
    body:JSON.stringify({action,payload,admin}),
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

  rpcError={message:'Device limit reached',code:'42501'};
  const restore=new Request('https://test.invalid/account',{method:'POST',
    headers:{Authorization:'Bearer test-session'},
    body:JSON.stringify({admin:true,action:'restore_device',payload:{id:'device-row'}})});
  const slotRes=await handler(restore);
  assert.equal(slotRes.status,409);
  assert.deepEqual(await slotRes.json(),{code:'DEVICE_LIMIT_REACHED',devices:[]});

  rpcError={message:'QUOTA_EXHAUSTED',code:'PT409'};
  const quotaRes=await handler(request('test-session',{},'reserve_operation'));
  assert.equal(quotaRes.status,409);
  assert.deepEqual(await quotaRes.json(),{code:'QUOTA_EXHAUSTED',quota_remaining:0});

  rpcError={message:'Device limit reached',code:'42501'};
  const full=await handler(request('test-session',{},'restore_device',true));
  assert.equal(full.status,409);
  assert.deepEqual(await full.json(),{code:'DEVICE_LIMIT_REACHED',devices:[]});

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
