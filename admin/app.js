import {createClient} from '@supabase/supabase-js';
const $=id=>document.getElementById(id);
let client,section='users';
const sections={dashboard:'Dashboard',users:'Users',devices:'Devices',entitlements:'Plans & Entitlements',flags:'Feature Flags',logs:'Audit Logs'};
function notice(text){$('notice').textContent=text;}
async function rpc(action,payload={}){
  const {data,error}=await client.functions.invoke('account',{body:{admin:true,action,payload}});
  if(error)throw Error('Yêu cầu bị từ chối. Kiểm tra quyền Admin và trạng thái tài khoản.');
  return data;
}
async function render(){
  $('heading').textContent=sections[section];
  const data=await rpc(section,{search:$('search').query.value});
  const rows=Array.isArray(data)?data:[data];
  $('records').replaceChildren();
  if(section==='dashboard'){
    $('summary').textContent=Object.entries(data).map(([key,value])=>`${key}: ${value}`).join(' · ');
    return;
  }
  $('summary').textContent=section==='dashboard'?`Trong tối đa 100 user gần nhất: ${rows.length} user · ${rows.filter(x=>x.account_status==='active').length} active · ${rows.filter(x=>['suspended','banned'].includes(x.account_status)).length} bị khóa`:`${rows.length} kết quả (tối đa 100)`;
  for(const row of rows){const card=document.createElement('article');const pre=document.createElement('pre');pre.textContent=JSON.stringify(row,null,2);card.append(pre);$('records').append(card);}
}
async function run(work){try{notice('Đang xử lý…');await work();notice('Hoàn tất');}catch(e){notice(e.message);}}
$('connect').onsubmit=e=>{e.preventDefault();run(async()=>{
  const uri=new URL($('url').value);if(uri.protocol!=='https:'&&uri.hostname!=='127.0.0.1')throw Error('Cần HTTPS');
  client=createClient(uri.href,$('key').value,{auth:{persistSession:false}});
  $('login').hidden=false;$('connect').hidden=true;
});};
$('login').onsubmit=e=>{e.preventDefault();run(async()=>{
  const {error}=await client.auth.signInWithPassword({email:e.target.email.value,password:e.target.password.value});
  e.target.password.value='';if(error)throw Error('Đăng nhập thất bại');
  try{await rpc('users');}catch(err){await client.auth.signOut();throw err;}
  $('panel').hidden=false;$('login').hidden=true;await render();
});};
for(const [key,label] of Object.entries(sections)){const button=document.createElement('button');button.textContent=label;button.onclick=()=>run(async()=>{section=key;await render();});$('navigation').append(button);}
$('search').onsubmit=e=>{e.preventDefault();run(render);};
$('action').onsubmit=e=>{e.preventDefault();run(async()=>{
  const payload=Object.fromEntries(new FormData(e.target));const action=payload.action;delete payload.action;
  payload.enabled=e.target.enabled.checked;
  if(payload.expires_at)payload.expires_at=new Date(payload.expires_at).toISOString();
  if(action!=='details'&&!confirm('Xác nhận thay đổi?'))return;
  $('detail').textContent=JSON.stringify(await rpc(action,payload),null,2);await render();
});};
$('password').onsubmit=e=>{e.preventDefault();run(async()=>{const {error}=await client.auth.updateUser({password:e.target.password.value});e.target.reset();if(error)throw Error('Không đổi được mật khẩu');});};
$('logout').onclick=()=>run(async()=>{await client.auth.signOut();$('panel').hidden=true;$('login').hidden=false;$('records').replaceChildren();$('detail').textContent='';});
