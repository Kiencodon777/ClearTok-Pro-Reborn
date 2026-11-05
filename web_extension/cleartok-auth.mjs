import {createClient} from '@supabase/supabase-js';
export function clearTokAuth(url,key){
  if(!url||!key)return {check:async()=>{throw Error('Cần cấu hình Supabase cho ClearTok');}};
  const storage={getItem:async k=>(await chrome.storage.session.get(k))[k]??null,
    setItem:async(k,v)=>chrome.storage.session.set({[k]:v}),
    removeItem:async k=>chrome.storage.session.remove(k)};
  const client=createClient(url,key,{auth:{storage,autoRefreshToken:true,persistSession:true,detectSessionInUrl:false}});
  const form=document.createElement('form'),email=document.createElement('input'),password=document.createElement('input'),status=document.createElement('p');
  email.type='email';email.placeholder='Email ClearTok';email.autocomplete='username';
  password.type='password';password.placeholder='Mật khẩu ClearTok';password.autocomplete='current-password';
  form.append(email,password,status);document.querySelector('main').prepend(form);
  async function work(fn){try{status.textContent='Đang xử lý…';await fn();status.textContent='Hoàn tất';}catch{status.textContent='Không thể hoàn tất. Kiểm tra tài khoản và xác minh email.';}finally{password.value='';}}
  for(const [label,fn] of [
    ['Đăng nhập',()=>client.auth.signInWithPassword({email:email.value,password:password.value})],
    ['Đăng ký',()=>client.auth.signUp({email:email.value,password:password.value})],
    ['Quên mật khẩu',()=>client.auth.resetPasswordForEmail(email.value)],
    ['Đăng xuất ClearTok',()=>client.auth.signOut()],
  ]){const button=document.createElement('button');button.type='button';button.textContent=label;button.onclick=()=>work(async()=>{const {error}=await fn();if(error)throw error;});form.append(button);}
  form.onsubmit=e=>e.preventDefault();
  return {check:async(feature)=>{
    const {data:{user},error}=await client.auth.getUser();if(error||!user)throw Error('Cần đăng nhập ClearTok');
    let {cleartokDeviceId}=await chrome.storage.local.get('cleartokDeviceId');
    if(!cleartokDeviceId){cleartokDeviceId=crypto.randomUUID();await chrome.storage.local.set({cleartokDeviceId});}
    const {data,error:failure}=await client.functions.invoke('account',{body:{action:'register_device',payload:{feature,device_id:cleartokDeviceId,platform:'extension',device_name:'ClearTok extension',app_version:chrome.runtime.getManifest().version}}});
    if(failure)throw Error('Tài khoản hoặc thiết bị ClearTok bị từ chối');
    status.textContent=`${user.email} · ${data.effective_plan}`;return user.id;
  }};
}
