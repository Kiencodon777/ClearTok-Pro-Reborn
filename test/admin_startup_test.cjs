const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');

test('admin opens login without connection fields and rejects unauthorized accounts',async()=>{
  const html=fs.readFileSync('admin/index.html','utf8');
  assert.ok(!html.includes('id="connect"'));
  assert.ok(html.includes('Open-Admin.cmd'));
  class Element {
    constructor(){this.hidden=true;this.children=[];this.classList={toggle(){}};}
    setAttribute(){}
    addEventListener(){}
    append(...children){this.children.push(...children);}
  }
  const elements=Object.fromEntries([...html.matchAll(/id="([^"]+)"/g)].map(m=>[m[1],new Element()]));
  elements.search.query={value:''};
  let signedOut=false,settings;
  const client={auth:{
    signInWithPassword:async()=>({data:{user:{id:'ordinary-user'}},error:null}),
    signOut:async()=>{signedOut=true;},
  },functions:{invoke:async()=>({error:new Error('Forbidden')})}};
  vm.runInNewContext(fs.readFileSync('admin/app.js','utf8').replace(/^import .*;\r?\n/,''),{
    document:{getElementById:id=>elements[id],createElement:()=>new Element(),createTextNode:text=>text},Node:Element,
    createClient:(url,key,options)=>{settings={url,key,options};return client;},
    setTimeout,clearTimeout,
  });
  assert.equal(elements.startup.hidden,true);
  assert.equal(elements.login.hidden,false);
  assert.equal(settings.url,'https://jsxxxbspjmpbaomotgcj.supabase.co');
  assert.ok(settings.key.startsWith('sb_publishable_'));
  assert.equal(settings.options.auth.persistSession,false);
  let prevented=false;
  const form={email:{value:'test@example.invalid'},password:{value:'test-only'}};
  elements.login.onsubmit({preventDefault(){prevented=true;},target:form});
  await new Promise(resolve=>setImmediate(resolve));
  assert.ok(prevented);
  assert.ok(signedOut);
  assert.equal(form.password.value,'');
  assert.equal(elements.login.hidden,false);
  assert.equal(elements.panel.hidden,true);
});
