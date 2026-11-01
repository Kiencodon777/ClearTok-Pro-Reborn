import {pageExecute} from './page-api.mjs';
import {modes,nextCursor,morePages,mergeItems,filterItems,analytics,csv,TaskControl} from './core.mjs';
const $=id=>document.getElementById(id);
let mode='repost',profile=null,tabId=null,items=[],selected=new Set(),history=[],logs=[],busy=false,control=null;
const isExtension=Boolean(globalThis.chrome?.scripting&&globalThis.chrome?.storage);
const key=()=>`library:${profile.secUid}:${mode}`;
function message(text,error=false){$('status').textContent=text;$('status').classList.toggle('error',error);}
function log(action,code,detail={}) {
  const allowed=['http_status','response_kind','response_length','elapsed_ms','readback_attempted','readback_confirmed','readback_liked','login_redirect','verification_hint'];
  logs.push({time:new Date().toISOString(),action,code,...Object.fromEntries(Object.entries(detail).filter(([k,v])=>allowed.includes(k)&&['number','boolean'].includes(typeof v)||k==='response_kind'&&['json','html','empty','text'].includes(v)))});
  logs=logs.slice(-300);$('log-output').textContent=JSON.stringify(logs,null,2);
  if(isExtension)chrome.storage.session.set({logs}).catch(()=>{});
}
function filtered(){return filterItems(items,{query:$('search').value,sort:$('sort').value,from:$('from').value,to:$('to').value});}
function render(){
  const list=filtered(),stats=analytics(items),fragment=document.createDocumentFragment();
  $('heading').textContent=`Quản lý ${modes[mode]}.`;$('library-title').textContent=`Danh sách ${modes[mode]}`;
  $('stat-total').textContent=stats.total;$('stat-done').textContent=history.length;$('stat-top').textContent=stats.top;
  const views=items.reduce((n,i)=>n+(i.views||0),0),likes=items.reduce((n,i)=>n+(i.likes||0),0);
  $('engagement').textContent=`${stats.creators} creator${views?' · Like/View '+(likes/views*100).toFixed(1)+'%':''}`;
  for(const item of list){
    const row=document.createElement('tr'),cell=document.createElement('td'),check=document.createElement('input');
    check.type='checkbox';check.checked=selected.has(item.id);check.disabled=busy;check.setAttribute('aria-label','Chọn '+item.author+' '+item.id);
    check.onchange=()=>{check.checked?selected.add(item.id):selected.delete(item.id);buttons();};cell.append(check);row.append(cell);
    for(const value of ['@'+item.author,item.title,item.time?new Date(item.time*1000).toLocaleDateString('vi-VN'):'—']){
      const td=document.createElement('td');td.textContent=value;row.append(td);
    }
    const linkCell=document.createElement('td'),link=document.createElement('a');
    link.href='https://www.tiktok.com/@'+encodeURIComponent(item.author)+(mode==='unfollow'?'':'/video/'+encodeURIComponent(item.id));
    link.textContent='TikTok ↗';link.target='_blank';link.rel='noopener noreferrer';linkCell.append(link);row.append(linkCell);fragment.append(row);
  }
  $('items').replaceChildren(fragment);$('empty').hidden=list.length>0;$('count').textContent=`${list.length} / ${items.length} mục · ${selected.size} đã chọn`;
  buttons();
}
function buttons(){
  $('run').textContent=`${mode==='unfollow'?'Hủy follow':mode==='unlike'?'Bỏ thích':'Hủy repost'} (${selected.size})`;
  for(const id of ['connect','refresh-tabs','tabs','limit','delay'])$(id).disabled=busy||!isExtension;
  $('scan').disabled=busy||!profile;$('run').disabled=busy||!profile||!selected.size;
  for(const id of ['select-all','unselect'])$(id).disabled=busy;
  for(const button of document.querySelectorAll('[data-mode]'))button.disabled=busy;
  $('pause').disabled=!busy;$('stop').disabled=!busy;
  $('pause').textContent=control?.paused?'Tiếp tục':'Tạm dừng';
}
async function execute(command,input={}){
  const watch=performance.now();
  try{
    const tab=await chrome.tabs.get(tabId);
    if(!tab.url?.startsWith('https://www.tiktok.com/'))throw Error('Tab TikTok đã đóng hoặc chuyển trang.');
    const results=await chrome.scripting.executeScript({target:{tabId},world:'MAIN',func:pageExecute,args:[command,input,profile?.secUid||'']});
    const value=results[0]?.result;if(value==null)throw Error('Tab TikTok không trả kết quả.');
    let details={};try{details=JSON.parse(value.raw||'{}');}catch(_){}
    log(`${command}.${input.mode||'session'}`,value.status_code??0,{...details,elapsed_ms:Math.round(performance.now()-watch)});
    return value;
  }catch(e){log(`${command}.${input.mode||'session'}`,-1,{elapsed_ms:Math.round(performance.now()-watch)});throw e;}
}
async function save(){await chrome.storage.local.set({[key()]:{items,history}});}
async function load(){selected.clear();const saved=(await chrome.storage.local.get(key()))[key()];items=saved?.items||[];history=saved?.history||[];render();}
async function task(work){
  if(busy||!profile)return;
  busy=true;control=new TaskControl();render();
  try{
    await navigator.locks.request('cleartok-job',{ifAvailable:true},async lock=>{
      if(!lock)throw Error('Một cửa sổ Studio khác đang xử lý.');
      await chrome.storage.session.set({unfinishedJob:true});
      try{await work(control);}finally{await chrome.storage.session.set({unfinishedJob:false});}
    });
  }catch(e){message(e.message,true);log('task.error',-1);}
  finally{busy=false;control=null;render();}
}
async function scan(ctrl){
  const limit=Number($('limit').value),seen=new Set([0]);let cursor=0,found=[];
  while(await ctrl.wait()){
    message(`Đang quét ${modes[mode]}… ${found.length}${limit?' / '+limit:''}`);
    const page=await execute('scan',{mode,cursor});
    found=mergeItems(found,page.items,limit);
    items=mergeItems(items,page.items.filter(i=>found.some(f=>f.id===i.id)));
    await save();render();$('progress-label').textContent=`Đã quét ${found.length}${limit?' / '+limit:''}`;
    $('progress').max=limit||Math.max(found.length,1);$('progress').value=found.length;
    if(limit&&found.length>=limit)break;
    const next=nextCursor(page,cursor);
    if(!morePages(page,page.items.length,next!==cursor))break;
    if(seen.has(next))throw Error(`TikTok lặp cursor sau ${found.length} mục. Chưa quét hết.`);
    seen.add(next);cursor=next;if(!await ctrl.wait(1500))break;
  }
  message(`${ctrl.stopped?'Đã dừng':'Quét xong'}: ${found.length} mục trong đợt này. Thư viện giữ cả dữ liệu đã quét trước.`);
}
async function run(ctrl){
  const queue=items.filter(i=>selected.has(i.id)),delay=Math.max(1500,Math.min(60000,Number($('delay').value)||2000));
  let done=0;$('progress').max=queue.length;$('progress').value=0;
  for(const item of queue){
    if(!await ctrl.wait())break;
    message(`Đang xử lý ${done+1}/${queue.length} · @${item.author}`);
    const result=await execute('mutate',{mode,item});
    if(!result.success){
      message(`Đã dừng · mã ${result.status_code}: ${result.message||'TikTok chưa xác nhận kết quả'}. Xem Nhật ký.`,true);
      return;
    }
    history.push({id:item.id,time:new Date().toISOString()});items=items.filter(i=>i.id!==item.id);selected.delete(item.id);done++;
    await save();render();$('progress').value=done;$('progress-label').textContent=`${done}/${queue.length} thành công`;
    if(done<queue.length&&!await ctrl.wait(delay))break;
  }
  message(`${ctrl.stopped?'Đã dừng':'Hoàn tất'}: ${done}/${queue.length} mục được TikTok xác nhận.`);
}
async function refreshTabs(){
  const tabs=await chrome.tabs.query({url:'https://www.tiktok.com/*'});$('tabs').replaceChildren();
  for(const tab of tabs){const option=document.createElement('option');option.value=tab.id;option.textContent=tab.title||`TikTok · ${tab.id}`;$('tabs').append(option);}
  if(!tabs.length){const option=document.createElement('option');option.value='';option.textContent='Chưa có tab TikTok';$('tabs').append(option);}
}
function download(name,text,type){const url=URL.createObjectURL(new Blob([text],{type}));const link=document.createElement('a');link.href=url;link.download=name;link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
const guard=fn=>async()=>{try{await fn();}catch(e){message(e.message,true);}};
$('open-tiktok').onclick=()=>isExtension?chrome.tabs.create({url:'https://www.tiktok.com/login'}):window.open('https://www.tiktok.com/login','_blank','noopener');
$('refresh-tabs').onclick=guard(refreshTabs);
$('connect').onclick=guard(async()=>{tabId=Number($('tabs').value);if(!tabId)throw Error('Mở TikTok và đăng nhập trước.');profile=null;profile=await execute('profile');$('account').textContent='@'+profile.uniqueId;await load();message('Đã kết nối @'+profile.uniqueId+'. Chọn chức năng và bắt đầu quét.');});
for(const button of document.querySelectorAll('[data-mode]'))button.onclick=guard(async()=>{
  if(busy)return;mode=button.dataset.mode;for(const b of document.querySelectorAll('[data-mode]'))b.setAttribute('aria-pressed',String(b===button));
  $('studio').hidden=false;$('logs').hidden=true;selected.clear();if(profile)await load();else{items=[];history=[];render();}
});
$('log-tab').onclick=()=>{$('studio').hidden=true;$('logs').hidden=false;};
for(const id of ['search','sort','from','to'])$(id).oninput=render;
$('scan').onclick=()=>task(scan);
$('run').onclick=()=>{if(confirm(`Xác nhận xử lý ${selected.size} mục trên @${profile?.uniqueId}? Thao tác thay đổi trực tiếp tài khoản TikTok.`))task(run);};
$('select-all').onclick=()=>{for(const i of filtered())selected.add(i.id);render();};$('unselect').onclick=()=>{selected.clear();render();};
$('pause').onclick=()=>{if(control){control.paused=!control.paused;buttons();message(control.paused?'Đã yêu cầu tạm dừng sau request đang chạy.':'Đang tiếp tục…');}};
$('stop').onclick=()=>{control?.stop();message('Đã yêu cầu dừng sau request đang chạy.');};
$('csv').onclick=()=>download(`cleartok-${mode}.csv`,csv(filtered()),'text/csv;charset=utf-8');
$('json').onclick=()=>download(`cleartok-${mode}.json`,JSON.stringify(filtered(),null,2),'application/json');
$('export-log').onclick=()=>download('cleartok-log.json',JSON.stringify(logs,null,2),'application/json');
$('clear-log').onclick=()=>{logs=[];$('log-output').textContent='[]';if(isExtension)chrome.storage.session.set({logs:[]});};
window.addEventListener('beforeunload',event=>{if(busy){event.preventDefault();event.returnValue='';}});
render();
if(isExtension){
  $('version').textContent='Web '+chrome.runtime.getManifest().version;
  const saved=await chrome.storage.session.get(['logs','unfinishedJob']);logs=saved.logs||[];$('log-output').textContent=JSON.stringify(logs,null,2);
  await refreshTabs();if(saved.unfinishedJob)message('Một tác vụ trước chưa xác nhận hoàn tất. Kiểm tra TikTok trước khi chạy lại; Studio không tự tiếp tục.',true);
}else message('Bản xem giao diện: hãy cài extension bằng Load unpacked, rồi bấm biểu tượng ClearTok để mở bản có kết nối TikTok.',true);
