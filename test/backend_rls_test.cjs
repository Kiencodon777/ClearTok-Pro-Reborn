const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {PGlite}=require('@electric-sql/pglite');

test('PostgreSQL migrations enforce ownership, privileges, device limits and admin audit',async()=>{
  const db=new PGlite();
  try {
    await db.exec(`create role anon; create role authenticated; create schema auth;
      create table auth.users(id uuid primary key,email text,email_confirmed_at timestamptz);
      create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated; grant execute on function auth.uid() to authenticated;`);
    for(const file of fs.readdirSync('supabase/migrations').sort())
      await db.exec(fs.readFileSync('supabase/migrations/'+file,'utf8'));
    await db.exec(fs.readFileSync('supabase/staging_rls_check.sql','utf8'));
    assert.equal((await db.query('select count(*) as count from auth.users')).rows[0].count,0);
    const a='00000000-0000-0000-0000-000000000001',b='00000000-0000-0000-0000-000000000002',admin='00000000-0000-0000-0000-000000000003';
    for(const id of [a,b,admin])await db.query('insert into auth.users values($1,$2,now())',[id,id+'@test.invalid']);
    await db.query("update public.profiles set role='admin' where id=$1",[admin]);
    async function as(id){await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[id]);await db.exec('set role authenticated');}
    await as(a);
    assert.equal((await db.query('select * from profiles')).rows.length,1);
    assert.equal((await db.query('update profiles set display_name=$1 where id=$2 returning id',['bad',b])).rows.length,0);
    await assert.rejects(db.exec("update profiles set role='admin'"));
    await assert.rejects(db.exec("update user_entitlements set plan='premium'"));
    await assert.rejects(db.query("select admin_api('users')"));
    await db.query("select account_api('register_device',$1)",[JSON.stringify({device_id:a,platform:'android'})]);
    await assert.rejects(db.query("select account_api('register_device',$1)",[JSON.stringify({device_id:b,platform:'ios'})]));
    await db.exec('begin; reset role');
    await db.query("update user_devices set last_seen_at=now()-interval '7 days' where user_id=$1",[a]);
    await as(a);
    await db.exec('savepoint seven_days');
    await assert.rejects(db.query("select account_api('register_device',$1)",[JSON.stringify({device_id:b,platform:'ios'})]));
    await db.exec('rollback to seven_days; commit');
    // Simulate reinstall after >7 days of inactivity on Free plan: stale device is auto-replaced
    await db.exec('reset role');
    await db.query("update public.user_devices set last_seen_at = now() - interval '8 days' where user_id = $1 and device_id = $2", [a, a]);
    await as(a);
    const staleReplaced = (await db.query("select account_api('register_device',$1) as data",[JSON.stringify({device_id:b,platform:'ios'})])).rows[0].data;
    assert.equal(staleReplaced.devices.filter(d => d.is_active).length, 1);
    assert.equal(staleReplaced.devices.find(d => d.is_active).device_id, b);
    const account = async (action,payload) => (await db.query(
      'select account_api($1,$2) as data',[action,JSON.stringify(payload)])).rows[0].data;
    const restored = staleReplaced.devices.find(d => !d.is_active);
    const active = staleReplaced.devices.find(d => d.is_active);
    const restore = () => db.query("select admin_api('restore_device',$1)",[JSON.stringify({id:restored.id})]);
    assert.equal(staleReplaced.quota_remaining,20);
    const updated = await account('register_device',{device_id:b,platform:'extension',device_name:'Browser',app_version:'2'});
    const metadata = updated.devices.find(d => d.id === active.id);
    assert.deepEqual([metadata.platform,metadata.device_name,metadata.app_version],['extension','Browser','2']);
    await assert.rejects(restore(),/Administrator required/);
    await as(admin);
    await assert.rejects(restore(),/Device limit reached/);
    await as(a);
    const operations = Array.from({length:21},(_,n) => ({
      device_id:b,operation_id:require('node:crypto').randomUUID(),feature:n%2?'repost':'unfollow',
    }));
    const reserve = payload => account('reserve_operation',payload);
    const settle = (payload,outcome) => account('settle_operation',{...payload,outcome});
    await assert.rejects(reserve({...operations[0],operation_id:'bad'}),/uuid/);
    await assert.rejects(settle(operations[0],'consumed'),/Invalid settlement/);
    await assert.rejects(reserve({...operations[0],device_id:a}),/Device unavailable/);
    await assert.rejects(db.query('select * from account_operations'),/permission denied/);
    for (const [n,op] of operations.slice(0,20).entries())
      assert.deepEqual(await reserve(op),{status:'reserved',quota_remaining:19-n});
    await assert.rejects(reserve(operations[20]),{code:'PT409',message:'QUOTA_EXHAUSTED'});
    assert.deepEqual(await reserve(operations[0]),{status:'reserved',quota_remaining:0});
    await assert.rejects(reserve({...operations[0],feature:'unlike'}),/identity mismatch/);
    assert.deepEqual(await settle(operations[0],'consumed'),{status:'consumed',quota_remaining:0});
    assert.equal((await reserve(operations[0])).status,'consumed');
    await assert.rejects(settle(operations[0],'released'),/already settled/);
    for(let retry=0;retry<2;retry++)
      assert.deepEqual(await settle(operations[1],'released'),{status:'released',quota_remaining:1});
    await account('revoke_device',{id:active.id});
    await as(admin);
    await restore();
    const log=(await db.query("select admin_api('logs') as data")).rows[0].data.find(l=>l.action==='restore_device');
    assert.deepEqual([log.admin_id,log.target_user_id,log.metadata.device_id],[admin,a,a]);
    await as(a);
    assert.deepEqual(await reserve({...operations[20],device_id:a}),{status:'reserved',quota_remaining:0});
    await db.exec('reset role');
    assert.equal((await db.query("select bool_and(quota_day = (now() at time zone 'Asia/Ho_Chi_Minh')::date) as ok from account_operations")).rows[0].ok,true);
    await db.exec("update account_operations set quota_day = quota_day - 1");
    await as(a);
    assert.deepEqual(await settle(operations[2],'released'),{status:'released',quota_remaining:20});
    await account('revoke_device',{id:restored.id});
    await as(admin);
    await db.query("select admin_api('premium',$1)",[JSON.stringify({user_id:a,plan:'premium'})]);
    await as(a);
    const unlimited = {...operations[0],operation_id:require('node:crypto').randomUUID()};
    const registered = await account('register_device',{device_id:admin,platform:'ios'});
    unlimited.device_id = admin;
    assert.equal(registered.quota_remaining,null);
    assert.deepEqual(await reserve(unlimited),{status:'reserved',quota_remaining:null});
    assert.deepEqual(await settle(unlimited,'consumed'),{status:'consumed',quota_remaining:null});
    await as(admin);
    assert.equal((await db.query("select admin_api('users') as data")).rows[0].data.length,3);
    assert.ok((await db.query("select admin_api('logs') as data")).rows[0].data.length>=2);
    await db.query("select admin_api('premium',$1)",[JSON.stringify({user_id:a,plan:'premium',expires_at:'2000-01-01T00:00:00Z'})]);
    await as(a);
    assert.equal((await db.query("select account_api('current') as data")).rows[0].data.effective_plan,'free');
    const device=(await db.query('select id from user_devices')).rows[0];
    await db.query("select account_api('revoke_device',$1)",[JSON.stringify({id:device.id})]);
    await assert.rejects(db.query("select account_api('register_device',$1)",[JSON.stringify({device_id:a,platform:'android'})]));
    await as(admin);
    await db.query("select admin_api('flag',$1)",[JSON.stringify({feature_key:'unlike',enabled:false,minimum_plan:'free'})]);
    await as(b);
    await assert.rejects(db.query("select account_api('current',$1)",[JSON.stringify({feature:'unlike'})]));
    await db.exec('reset role');
    const competing='00000000-0000-0000-0000-000000000005';
    await db.query('insert into auth.users values($1,$2,now())',[competing,'competing@test.invalid']);
    await as(competing);
    const enrollment=await Promise.allSettled([a,b].map(device_id=>db.query("select account_api('register_device',$1)",[JSON.stringify({device_id,platform:'android'})])));
    assert.equal(enrollment.filter(x=>x.status==='fulfilled').length,1);
    assert.equal((await db.query('select count(*)::int as n from user_devices where is_active')).rows[0].n,1);
    await db.exec('reset role');
    const rateUser='00000000-0000-0000-0000-000000000004';
    await db.query('insert into auth.users values($1,$2,now())',[rateUser,'rate@test.invalid']);
    await as(rateUser);
    await db.exec('begin');
    for(let n=0;n<120;n++)await db.query("select account_api('current')");
    await db.exec('savepoint boundary');
    await assert.rejects(db.query("select account_api('current')"),/Rate limit exceeded/);
    await db.exec('rollback to boundary; commit');
    await as(admin);
    await db.query("select admin_api('status',$1)",[JSON.stringify({user_id:a,status:'suspended'})]);
    await as(a);await assert.rejects(db.query("select account_api('current')"));
  } finally {await db.close();}
});
