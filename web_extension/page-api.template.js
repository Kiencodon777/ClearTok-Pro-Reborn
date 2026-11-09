// Build embeds the mobile transport here, without eval or remote scripts.
export async function pageExecute(command, input, expectedUser) {
  if(location.origin!=='https://www.tiktok.com')throw Error('Cần trang www.tiktok.com.');
  const candidates=[window['__$UNIVERSAL_DATA$__'],window['__UNIVERSAL_DATA_FOR_REHYDRATION__']];
  try{candidates.push(JSON.parse(document.getElementById('__UNIVERSAL_DATA_FOR_REHYDRATION__')?.textContent||'{}'));}catch(_){}
  const app=candidates.map(x=>x?.__DEFAULT_SCOPE__?.['webapp.app-context']).find(x=>x?.user?.secUid);
  if(!app)throw Error('Chưa tìm thấy phiên đăng nhập. Đăng nhập TikTok và tải lại trang.');
  const user={id:String(app.user.id||app.user.uid||''),secUid:String(app.user.secUid),
    uniqueId:String(app.user.uniqueId||''),nickname:String(app.user.nickname||'')};
  if(command==='profile')return user;
  if(!expectedUser||expectedUser!==user.secUid)throw Error('Tài khoản TikTok đã thay đổi; kết nối lại trước khi tiếp tục.');
  const endpoints={repost:'/api/repost/item_list/',unlike:'/api/favorite/item_list/',unfollow:'/api/user/list/'};
  if(!Object.hasOwn(endpoints,input.mode))throw Error('Chế độ không hợp lệ.');
  if(command==='mutate') {
    if(!/^\d+$/.test(input.item?.id||''))throw Error('ID thao tác không hợp lệ.');
    const aid=1988;
    /* MOBILE_BRIDGE */
    const path=input.mode==='repost'?'/tiktok/v1/upvote/delete':input.mode==='unlike'?'/api/commit/item/digg/':'/api/commit/follow/user/';
    const params=input.mode==='repost'?{item_id:input.item.id,type:'1'}:input.mode==='unlike'?{aweme_id:input.item.id,type:'0',_author:input.item.author}:
      {user_id:input.item.id,sec_user_id:input.item.secUid||'',type:'0',action_type:'0',channel_id:'0',from:'18',fromWeb:'1',from_pre:'0'};
    return JSON.parse(await (async()=>{ /* MOBILE_TRANSPORT */ })());
  }
  if(command!=='scan')throw Error('Lệnh không hợp lệ.');
  const cursor=Number(input.cursor);
  if(!Number.isSafeInteger(cursor)||cursor<0)throw Error('Cursor không hợp lệ.');
  const url=new URL(endpoints[input.mode],location.origin);
  for(const [k,v] of Object.entries({aid:1988,count:30,secUid:user.secUid,app_name:'tiktok_web',device_platform:'web_pc',
    device_id:app.wid,odinId:app.odinId,WebIdLastTime:app.webIdCreatedTime})) {
    if(v!=null)url.searchParams.set(k,String(v));
  }
  if(input.mode==='unfollow') {url.searchParams.set('scene','21');url.searchParams.set('minCursor','0');url.searchParams.set('maxCursor',String(cursor));}
  else {url.searchParams.set('cursor',String(cursor));url.searchParams.set('coverFormat','2');}
  const abort=new AbortController(),timer=setTimeout(()=>abort.abort(),20000);
  try {
    const response=await fetch(url,{credentials:'include',signal:abort.signal});
    const raw=await response.text();
    if(!response.ok)throw Error('TikTok HTTP '+response.status);
    let data;try{data=JSON.parse(raw);}catch(_){throw Error(`TikTok HTTP ${response.status}, ${raw.length?'không phải JSON':'body rỗng'}; chưa quét xong.`);}
    if(String(data.status_code)!=='0')throw Error('TikTok từ chối quét: '+String(data.status_code));
    const list=input.mode==='unfollow'?data.userList:data.itemList;
    if(!Array.isArray(list))throw Error('Phản hồi không có danh sách hợp lệ.');
    const items=list.map(x=>{
      const u=input.mode==='unfollow'?(x.user||x):(x.author||{});
      return {id:String(input.mode==='unfollow'?(u.id||u.uid||''):x.id||''),
        secUid:String(u.secUid||u.sec_uid||''),author:String(u.uniqueId||u.unique_id||''),
        title:String(input.mode==='unfollow'?(u.nickname||''):x.desc||''),
        time:Number(x.repostTime||x.createTime||0),likes:Number(x.stats?.diggCount||0),
        views:Number(x.stats?.playCount||0)};
    });
    return {items,cursor:data.cursor,maxCursor:data.maxCursor,max_cursor:data.max_cursor,
      minCursor:data.minCursor,min_cursor:data.min_cursor,hasMore:data.hasMore,has_more:data.has_more};
  } finally{clearTimeout(timer);}
}
