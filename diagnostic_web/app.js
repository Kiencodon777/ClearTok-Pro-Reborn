const byId = id => document.getElementById(id);
function diagnose(entry) {
  if (entry.action?.endsWith('.start')) return null;
  if (entry.code === 0) return `${entry.action}: thành công${entry.readback_confirmed ? ' (đã đọc lại trạng thái)' : ''}.`;
  if (entry.code === 10402) return `${entry.action}: CSRF thiếu hoặc bị server từ chối.`;
  if (entry.http_status === 200 && entry.response_kind === 'empty') {
    return `${entry.action}: HTTP 200, body rỗng. Kết quả thao tác chưa được server xác nhận. Đây chưa phải bằng chứng CSRF sai hay hết phiên. `+
      (entry.readback_confirmed ? `Đọc lại: video ${entry.readback_liked ? 'vẫn đang được thích' : 'không còn thích'}.` : 'Chưa có xác nhận trạng thái; không tự gửi lại POST.');
  }
  if (entry.login_redirect) return `${entry.action}: chuyển về đăng nhập; kiểm tra phiên.`;
  if (entry.verification_hint) return `${entry.action}: có dấu hiệu trang xác minh; mở TikTok Web để kiểm tra thủ công.`;
  return `${entry.action}: mã ${entry.code}, HTTP ${entry.http_status ?? 'không ghi nhận'}, dạng ${entry.response_kind ?? 'không ghi nhận'}. Cần thêm dữ liệu để xác định nguyên nhân.`;
}
byId('analyze').onclick = () => {
  try {
    const entries = JSON.parse(byId('logs').value);
    if (!Array.isArray(entries) || entries.length > 10000) throw Error('Cần một mảng JSON, tối đa 10000 sự kiện.');
    byId('diagnosis').textContent = entries.filter(e=>e && typeof e==='object').map(diagnose).filter(Boolean).join('\n\n') || 'Không có sự kiện để phân tích.';
  } catch(e) { byId('diagnosis').textContent = 'Không đọc được log: '+e.message; }
};
byId('example').onclick = () => {
  byId('logs').value = JSON.stringify([{action:'unlike',code:-2,http_status:200,response_length:0,response_kind:'empty',csrf_present:true}, {action:'unfollow',code:0,http_status:200,response_kind:'json'}],null,2);
  byId('analyze').click();
};
byId('tests').onclick = async () => {
  const button = byId('tests'); button.disabled = true;
  const lines = [];
  try {
    for (const [name,raw,status,code] of [['OK','{"status_code":0}',200,0],['Empty 200','',200,-2],['CSRF','{"status_code":10402}',200,10402],['HTML','<html>',200,-2],['HTTP 403','{}',403,403]]) {
      let requests=0;
      const fetch=async url=>{requests++;return {ok:status===200,status,url,headers:{get:()=>null},text:async()=>raw};};
      const fakeDocument={getElementById:()=>({textContent:JSON.stringify({__DEFAULT_SCOPE__:{'webapp.app-context':{csrfToken:'test',wid:'test-device'}}})})};
      const result=JSON.parse(await window.mobileTransport({fetch},fakeDocument,{origin:'https://www.tiktok.com'},{language:'vi',platform:'iPhone',userAgent:'test'},'/api/commit/item/digg/',{aweme_id:'test-video',type:'0'},1988));
      lines.push(`${result.status_code===code && requests===1 ? 'PASS':'FAIL'} · ${name} · code ${result.status_code} · ${requests} request`);
    }
  } catch(e) { lines.push('FAIL · '+e.message); }
  finally { button.disabled=false; byId('results').textContent=lines.join('\n'); }
};
