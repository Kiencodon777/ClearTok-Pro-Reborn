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
    await as(admin);
    await db.query("select admin_api('premium',$1)",[JSON.stringify({user_id:a,plan:'premium'})]);
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
    await as(admin);
    await db.query("select admin_api('status',$1)",[JSON.stringify({user_id:a,status:'suspended'})]);
    await as(a);await assert.rejects(db.query("select account_api('current')"));
  } finally {await db.close();}
});
