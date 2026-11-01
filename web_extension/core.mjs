export const modes = {repost:'Reposts', unlike:'Likes', unfollow:'Following'};
export function nextCursor(data, current) {
  for (const key of ['cursor','maxCursor','max_cursor','minCursor','min_cursor']) {
    const value = Number(data[key]);
    if (Number.isSafeInteger(value) && value>0 && value!==current) return value;
  }
  return current;
}
export function morePages(data, count, advanced) {
  const flag=data.hasMore??data.has_more;
  if ([false,0,'0','false'].includes(flag)) return false;
  if (count && !advanced && [true,1,'1','true'].includes(flag)) throw Error('TikTok thiếu cursor tiếp theo; kết quả chưa đầy đủ.');
  return count>0 && advanced;
}
export function mergeItems(existing, incoming, limit=0) {
  const items=new Map(existing.map(i=>[i.id,i]));
  for (const item of incoming) {
    if (!item.id) continue;
    if (!items.has(item.id) && limit>0 && items.size>=limit) break;
    items.set(item.id,item);
  }
  return [...items.values()];
}
export function filterItems(items,{query='',sort='new',from='',to=''}={}) {
  const q=query.trim().toLocaleLowerCase();
  const start=from?new Date(from+'T00:00:00').getTime():-Infinity;
  const end=to?new Date(to+'T23:59:59.999').getTime():Infinity;
  return items.filter(i=>(!q||[i.author,i.title,i.id].join(' ').toLocaleLowerCase().includes(q)) &&
    (!i.time||i.time*1000>=start&&i.time*1000<=end)).sort((a,b)=>sort==='author'?
    a.author.localeCompare(b.author):(sort==='old'?1:-1)*((a.time||0)-(b.time||0)));
}
export function analytics(items) {
  const creators=new Map();
  for(const i of items) creators.set(i.author,(creators.get(i.author)||0)+1);
  const top=[...creators].sort((a,b)=>b[1]-a[1])[0];
  return {total:items.length,creators:creators.size,top:top?`${top[0]} · ${top[1]}`:'—'};
}
export function csv(items) {
  const cell=value=>{let s=String(value??'');if(/^[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replaceAll('"','""')+'"';};
  return '\uFEFF'+['id,author,title,time',...items.map(i=>[i.id,i.author,i.title,i.time].map(cell).join(','))].join('\r\n');
}
export class TaskControl {
  stopped=false; paused=false;
  stop(){this.stopped=true;this.paused=false;}
  async wait(ms=0) {
    let remaining=ms;
    while(this.paused||remaining>0) {
      if(this.stopped)return false;
      await new Promise(r=>setTimeout(r,Math.min(100,remaining||100)));
      if(!this.paused)remaining-=100;
    }
    return !this.stopped;
  }
}
