import {createClient} from '@supabase/supabase-js';

const $ = id => document.getElementById(id);
let client;
let section = 'dashboard';
let currentAdminId = null;
let searchDebounce = null;

const sections = {
  dashboard: 'Dashboard',
  users: 'Người dùng (Users)',
  devices: 'Thiết bị (Devices)',
  entitlements: 'Gói cước (Plans)',
  flags: 'Tính năng (Flags)',
  logs: 'Nhật ký (Audit Logs)',
};

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === null || v === undefined || v === false) continue;
    if (k === 'className') node.className = v;
    else if (k === 'style') node.setAttribute('style', v);
    else if (k.startsWith('on') && typeof v === 'function') {
      node.addEventListener(k.slice(2).toLowerCase(), v);
    } else if (v === true) node.setAttribute(k, '');
    else node.setAttribute(k, String(v));
  }
  for (const child of children.flat()) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
  return node;
}

function notice(text) {
  $('notice').textContent = text;
}

function fmtDate(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  return d.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function shortId(uuid) {
  if (!uuid) return '—';
  const s = String(uuid);
  return s.length > 12 ? `${s.slice(0, 8)}…${s.slice(-4)}` : s;
}

function statusBadge(status) {
  const s = status || 'unknown';
  const cls =
    s === 'active'
      ? 'badge badge-active'
      : s === 'pending_verification'
        ? 'badge badge-pending'
        : 'badge badge-locked';
  const label =
    s === 'active'
      ? 'Hoạt động'
      : s === 'pending_verification'
        ? 'Chờ xác minh'
        : s === 'suspended'
          ? 'Tạm khóa'
          : s === 'banned'
            ? 'Cấm vĩnh viễn'
            : s;
  return el('span', {className: cls}, label);
}

function planBadge(plan, expiresAt) {
  const isPrem = plan === 'premium';
  const expired = isPrem && expiresAt && new Date(expiresAt) <= new Date();
  if (isPrem && !expired) {
    return el('span', {className: 'badge badge-premium'}, '★ PREMIUM');
  }
  if (isPrem && expired) {
    return el('span', {className: 'badge badge-pending'}, 'PREMIUM (Hết hạn)');
  }
  return el('span', {className: 'badge badge-free'}, 'FREE');
}

async function rpc(action, payload = {}) {
  const {data, error} = await client.functions.invoke('account', {
    body: {admin: true, action, payload},
  });
  if (error) {
    throw Error('Yêu cầu bị từ chối. Kiểm tra quyền Admin và trạng thái tài khoản.');
  }
  return data;
}

async function run(work) {
  try {
    notice('Đang xử lý…');
    await work();
    notice('Hoàn tất');
  } catch (e) {
    notice(e.message || 'Đã xảy ra lỗi');
  }
}

function openModal(title, contentNode) {
  $('modal-title').textContent = title;
  $('modal-body').replaceChildren(contentNode);
  $('modal-backdrop').hidden = false;
}

function closeModal() {
  $('modal-backdrop').hidden = true;
  $('modal-body').replaceChildren();
}

$('modal-close').onclick = closeModal;
$('modal-backdrop').onclick = e => {
  if (e.target === $('modal-backdrop')) closeModal();
};

async function openUserDetailModal(userId, emailHint = '') {
  await run(async () => {
    const detail = await rpc('details', {user_id: userId});
    const profile = detail.profile || {};
    const ent = detail.entitlement || {};
    const devices = Array.isArray(detail.devices) ? detail.devices : [];

    const addDaysIso = days => {
      const d = new Date();
      d.setDate(d.getDate() + days);
      return d.toISOString();
    };

    const applyPremium = async (plan, expiresAt) => {
      await run(async () => {
        await rpc('premium', {
          user_id: userId,
          plan,
          expires_at: expiresAt || '',
        });
        await openUserDetailModal(userId, emailHint);
        await render();
      });
    };

    const applyStatus = async newStatus => {
      if (!confirm(`Đổi trạng thái của ${profile.email || userId} sang "${newStatus}"?`)) return;
      await run(async () => {
        await rpc('status', {user_id: userId, status: newStatus});
        await openUserDetailModal(userId, emailHint);
        await render();
      });
    };

    const body = el(
      'div',
      {className: 'field-stack'},
      el(
        'div',
        {style: 'display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap'},
        el(
          'div',
          {},
          el('div', {style: 'font-size:17px;font-weight:700'}, profile.email || emailHint || 'Người dùng'),
          el('div', {className: 'mono'}, `UUID: ${userId}`),
        ),
        el(
          'div',
          {style: 'display:flex;gap:8px;align-items:center'},
          profile.role === 'admin' ? el('span', {className: 'badge badge-admin'}, 'ADMIN') : null,
          statusBadge(profile.account_status),
          planBadge(ent.plan, ent.expires_at),
        ),
      ),
      el(
        'div',
        {style: 'padding:14px;border-radius:14px;background:rgba(255,255,255,0.03);border:1px solid var(--border)'},
        el('div', {style: 'font-weight:700;margin-bottom:8px;color:var(--cyan)'}, '1. Thao tác nhanh Gói cước (Entitlement)'),
        el(
          'div',
          {style: 'font-size:12px;color:var(--secondary);margin-bottom:10px'},
          `Gói hiện tại: ${(ent.plan || 'free').toUpperCase()} · Hết hạn: ${fmtDate(ent.expires_at)}`,
        ),
        el(
          'div',
          {className: 'row-actions'},
          el('button', {type: 'button', className: 'btn-sm btn-pink', onClick: () => applyPremium('premium', addDaysIso(30))}, '★ Cấp Premium +30 ngày'),
          el('button', {type: 'button', className: 'btn-sm btn-pink', onClick: () => applyPremium('premium', addDaysIso(90))}, '★ Cấp Premium +90 ngày'),
          el('button', {type: 'button', className: 'btn-sm btn-pink', onClick: () => applyPremium('premium', addDaysIso(365))}, '★ Cấp Premium +1 năm'),
          el('button', {type: 'button', className: 'btn-sm btn-primary', onClick: () => applyPremium('premium', '')}, '★ Premium Vĩnh viễn'),
          el('button', {type: 'button', className: 'btn-sm', onClick: () => applyPremium('free', '')}, 'Chuyển về Free'),
        ),
      ),
      el(
        'div',
        {style: 'padding:14px;border-radius:14px;background:rgba(255,255,255,0.03);border:1px solid var(--border)'},
        el('div', {style: 'font-weight:700;margin-bottom:8px;color:var(--secondary)'}, '2. Trạng thái tài khoản'),
        profile.id === currentAdminId
          ? el('div', {style: 'font-size:12px;color:var(--muted)'}, 'Không thể tự khóa tài khoản Admin đang đăng nhập.')
          : el(
              'div',
              {className: 'row-actions'},
              el('button', {type: 'button', className: 'btn-sm btn-primary', onClick: () => applyStatus('active')}, '✓ Kích hoạt (Active)'),
              el('button', {type: 'button', className: 'btn-sm', onClick: () => applyStatus('suspended')}, '⏸ Tạm khóa (Suspend)'),
              el('button', {type: 'button', className: 'btn-sm btn-danger', onClick: () => applyStatus('banned')}, '⛔ Cấm vĩnh viễn (Ban)'),
            ),
      ),
      el(
        'div',
        {style: 'padding:14px;border-radius:14px;background:rgba(255,255,255,0.03);border:1px solid var(--border)'},
        el('div', {style: 'font-weight:700;margin-bottom:8px'}, `3. Thiết bị đã đăng ký (${devices.length})`),
        devices.length === 0
          ? el('div', {style: 'color:var(--muted);font-size:13px'}, 'Chưa có thiết bị nào được ghi nhận.')
          : el(
              'div',
              {className: 'field-stack'},
              devices.map(d =>
                el(
                  'div',
                  {style: 'display:flex;align-items:center;justify-content:space-between;gap:10px;padding:10px;border-radius:10px;background:rgba(0,0,0,0.3)'},
                  el(
                    'div',
                    {},
                    el('div', {style: 'font-weight:600'}, `${d.device_name || d.platform} (${d.platform})`),
                    el('div', {className: 'mono'}, `Version: ${d.app_version || '—'} · Hoạt động: ${fmtDate(d.last_seen_at)}`),
                  ),
                  d.is_active
                    ? el(
                        'button',
                        {
                          type: 'button',
                          className: 'btn-sm btn-danger',
                          onClick: async () => {
                            if (!confirm('Thu hồi thiết bị này?')) return;
                            await run(async () => {
                              await rpc('revoke_device', {id: d.id});
                              await openUserDetailModal(userId, emailHint);
                              await render();
                            });
                          },
                        },
                        'Thu hồi',
                      )
                    : el('span', {className: 'badge badge-locked'}, 'Đã thu hồi'),
                ),
              ),
            ),
      ),
    );

    openModal(`Quản trị tài khoản: ${profile.email || shortId(userId)}`, body);
  });
}

function renderDashboard(data) {
  const total = Number(data.total_users || 0);
  const active = Number(data.active_users || 0);
  const locked = Number(data.locked_users || 0);
  const new7d = Number(data.new_users_7_days || 0);
  const premium = Number(data.premium_users || 0);
  const devices = Number(data.active_devices || 0);
  const premRate = total > 0 ? Math.round((premium / total) * 100) : 0;

  $('summary').textContent = `Tổng quan thời gian thực · Tỷ lệ Premium: ${premRate}%`;

  const metrics = el(
    'div',
    {className: 'metrics-grid'},
    el(
      'div',
      {className: 'metric-card'},
      el('span', {className: 'm-label'}, 'Tổng người dùng'),
      el('span', {className: 'm-val', style: 'color:var(--cyan)'}, total),
      el('span', {className: 'm-sub'}, `+${new7d} trong 7 ngày qua`),
    ),
    el(
      'div',
      {className: 'metric-card'},
      el('span', {className: 'm-label'}, 'Đang hoạt động'),
      el('span', {className: 'm-val', style: 'color:var(--emerald)'}, active),
      el('span', {className: 'm-sub'}, `${locked} tài khoản đang khóa`),
    ),
    el(
      'div',
      {className: 'metric-card'},
      el('span', {className: 'm-label'}, 'Thuê bao Premium'),
      el('span', {className: 'm-val', style: 'color:var(--pink)'}, premium),
      el('span', {className: 'm-sub'}, `${premRate}% tổng số tài khoản`),
    ),
    el(
      'div',
      {className: 'metric-card'},
      el('span', {className: 'm-label'}, 'Thiết bị Active'),
      el('span', {className: 'm-val'}, devices),
      el('span', {className: 'm-sub'}, 'Giới hạn Free=1, Prem=5'),
    ),
  );

  const quickBar = el(
    'div',
    {style: 'display:flex;gap:10px;flex-wrap:wrap;margin-top:8px'},
    el(
      'button',
      {
        type: 'button',
        className: 'btn-primary',
        onClick: () => switchSection('users'),
      },
      'Quản lý danh sách người dùng →',
    ),
    el(
      'button',
      {
        type: 'button',
        onClick: () => switchSection('devices'),
      },
      'Kiểm tra thiết bị đang kết nối →',
    ),
    el(
      'button',
      {
        type: 'button',
        onClick: () => switchSection('flags'),
      },
      'Cấu hình Feature Flags →',
    ),
  );

  $('records').replaceChildren(metrics, quickBar);
}

function renderUsers(rows) {
  $('summary').textContent = `${rows.length} người dùng (tối đa 100 kết quả gần nhất)`;
  if (rows.length === 0) {
    $('records').replaceChildren(el('p', {style: 'color:var(--muted)'}, 'Không tìm thấy người dùng nào khớp từ khóa.'));
    return;
  }
  const table = el(
    'div',
    {className: 'table-wrap'},
    el(
      'table',
      {},
      el(
        'thead',
        {},
        el(
          'tr',
          {},
          el('th', {}, 'Người dùng'),
          el('th', {}, 'Vai trò'),
          el('th', {}, 'Trạng thái'),
          el('th', {}, 'Đăng nhập cuối'),
          el('th', {}, 'Ngày tạo'),
          el('th', {}, 'Thao tác nhanh'),
        ),
      ),
      el(
        'tbody',
        {},
        rows.map(u => {
          const initial = (u.email || '?').trim()[0]?.toUpperCase() || 'U';
          const isSelf = u.id === currentAdminId;
          return el(
            'tr',
            {},
            el(
              'td',
              {},
              el(
                'div',
                {className: 'user-cell'},
                el('div', {className: 'avatar'}, initial),
                el(
                  'div',
                  {},
                  el('div', {style: 'font-weight:700'}, u.email || '—'),
                  el('div', {className: 'mono', title: u.id}, shortId(u.id)),
                ),
              ),
            ),
            el(
              'td',
              {},
              u.role === 'admin'
                ? el('span', {className: 'badge badge-admin'}, 'ADMIN')
                : el('span', {className: 'badge badge-free'}, 'USER'),
            ),
            el('td', {}, statusBadge(u.account_status)),
            el('td', {className: 'mono'}, fmtDate(u.last_login_at)),
            el('td', {className: 'mono'}, fmtDate(u.created_at)),
            el(
              'td',
              {},
              el(
                'div',
                {className: 'row-actions'},
                el(
                  'button',
                  {
                    type: 'button',
                    className: 'btn-sm btn-primary',
                    onClick: () => openUserDetailModal(u.id, u.email),
                  },
                  'Chi tiết / Gói cước',
                ),
                !isSelf
                  ? el(
                      'button',
                      {
                        type: 'button',
                        className: u.account_status === 'active' ? 'btn-sm btn-danger' : 'btn-sm',
                        onClick: async () => {
                          const next = u.account_status === 'active' ? 'suspended' : 'active';
                          if (!confirm(`Đổi trạng thái ${u.email} sang "${next}"?`)) return;
                          await run(async () => {
                            await rpc('status', {user_id: u.id, status: next});
                            await render();
                          });
                        },
                      },
                      u.account_status === 'active' ? 'Tạm khóa' : 'Kích hoạt',
                    )
                  : null,
              ),
            ),
          );
        }),
      ),
    ),
  );
  $('records').replaceChildren(table);
}

function renderDevices(rows) {
  $('summary').textContent = `${rows.length} thiết bị ghi nhận (tối đa 100)`;
  if (rows.length === 0) {
    $('records').replaceChildren(el('p', {style: 'color:var(--muted)'}, 'Chưa có thiết bị nào được đăng ký.'));
    return;
  }
  const table = el(
    'div',
    {className: 'table-wrap'},
    el(
      'table',
      {},
      el(
        'thead',
        {},
        el(
          'tr',
          {},
          el('th', {}, 'Thiết bị & Nền tảng'),
          el('th', {}, 'User UUID'),
          el('th', {}, 'Phiên bản App'),
          el('th', {}, 'Hoạt động cuối'),
          el('th', {}, 'Trạng thái'),
          el('th', {}, 'Thao tác'),
        ),
      ),
      el(
        'tbody',
        {},
        rows.map(d =>
          el(
            'tr',
            {},
            el(
              'td',
              {},
              el('div', {style: 'font-weight:700'}, d.device_name || d.platform || 'Thiết bị'),
              el('div', {className: 'mono'}, `${(d.platform || '').toUpperCase()} · ID: ${shortId(d.device_id)}`),
            ),
            el(
              'td',
              {},
              el(
                'button',
                {
                  type: 'button',
                  className: 'btn-sm mono',
                  onClick: () => openUserDetailModal(d.user_id),
                },
                shortId(d.user_id),
              ),
            ),
            el('td', {className: 'mono'}, d.app_version || '—'),
            el('td', {className: 'mono'}, fmtDate(d.last_seen_at)),
            el(
              'td',
              {},
              d.is_active
                ? el('span', {className: 'badge badge-active'}, 'Đang hoạt động')
                : el('span', {className: 'badge badge-locked'}, 'Đã thu hồi'),
            ),
            el(
              'td',
              {},
              d.is_active
                ? el(
                    'button',
                    {
                      type: 'button',
                      className: 'btn-sm btn-danger',
                      onClick: async () => {
                        if (!confirm('Xác nhận thu hồi quyền truy cập của thiết bị này?')) return;
                        await run(async () => {
                          await rpc('revoke_device', {id: d.id});
                          await render();
                        });
                      },
                    },
                    'Thu hồi',
                  )
                : el('span', {style: 'color:var(--muted);font-size:12px'}, '—'),
            ),
          ),
        ),
      ),
    ),
  );
  $('records').replaceChildren(table);
}

function renderEntitlements(rows) {
  $('summary').textContent = `${rows.length} bản ghi quyền lợi gói cước`;
  const table = el(
    'div',
    {className: 'table-wrap'},
    el(
      'table',
      {},
      el(
        'thead',
        {},
        el(
          'tr',
          {},
          el('th', {}, 'User UUID'),
          el('th', {}, 'Gói cước'),
          el('th', {}, 'Trạng thái gói'),
          el('th', {}, 'Ngày hết hạn'),
          el('th', {}, 'Cập nhật cuối'),
          el('th', {}, 'Thao tác'),
        ),
      ),
      el(
        'tbody',
        {},
        rows.map(e =>
          el(
            'tr',
            {},
            el('td', {className: 'mono'}, e.user_id),
            el('td', {}, planBadge(e.plan, e.expires_at)),
            el('td', {}, statusBadge(e.status)),
            el('td', {className: 'mono'}, fmtDate(e.expires_at)),
            el('td', {className: 'mono'}, fmtDate(e.updated_at)),
            el(
              'td',
              {},
              el(
                'button',
                {
                  type: 'button',
                  className: 'btn-sm btn-pink',
                  onClick: () => openUserDetailModal(e.user_id),
                },
                'Đổi gói / Gia hạn',
              ),
            ),
          ),
        ),
      ),
    ),
  );
  $('records').replaceChildren(table);
}

function renderFlags(rows) {
  $('summary').textContent = `${rows.length} cờ tính năng hệ thống`;
  const labels = {
    repost: 'Xóa Video Đăng Lại (Reposts)',
    unlike: 'Bỏ Thích Hàng Loạt (Un-Like)',
    unfollow: 'Hủy Theo Dõi Hàng Loạt (Un-Follow)',
  };
  const grid = el(
    'div',
    {className: 'flags-grid'},
    rows.map(f => {
      const planSelect = el(
        'select',
        {className: 'btn-sm'},
        el('option', {value: 'free', selected: f.minimum_plan === 'free'}, 'Yêu cầu tối thiểu: FREE'),
        el('option', {value: 'premium', selected: f.minimum_plan === 'premium'}, 'Yêu cầu tối thiểu: PREMIUM'),
      );
      const toggleBtn = el(
        'button',
        {
          type: 'button',
          className: f.enabled ? 'btn-sm btn-primary' : 'btn-sm btn-danger',
          onClick: async () => {
            await run(async () => {
              await rpc('flag', {
                feature_key: f.feature_key,
                enabled: !f.enabled,
                minimum_plan: planSelect.value,
              });
              await render();
            });
          },
        },
        f.enabled ? 'Đang BẬT (Nhấn để Tắt)' : 'Đang TẮT (Nhấn để Bật)',
      );
      planSelect.onchange = async () => {
        await run(async () => {
          await rpc('flag', {
            feature_key: f.feature_key,
            enabled: Boolean(f.enabled),
            minimum_plan: planSelect.value,
          });
          await render();
        });
      };

      return el(
        'div',
        {className: 'flag-card'},
        el(
          'div',
          {style: 'display:flex;align-items:center;justify-content:space-between;gap:8px'},
          el(
            'div',
            {},
            el('div', {style: 'font-weight:700;font-size:15px'}, labels[f.feature_key] || f.feature_key),
            el('div', {className: 'mono'}, `key: ${f.feature_key}`),
          ),
          f.enabled
            ? el('span', {className: 'badge badge-active'}, 'ENABLED')
            : el('span', {className: 'badge badge-locked'}, 'DISABLED'),
        ),
        el('div', {style: 'display:flex;gap:8px;align-items:center;flex-wrap:wrap'}, planSelect, toggleBtn),
        el('div', {className: 'mono', style: 'font-size:11px'}, `Cập nhật: ${fmtDate(f.updated_at)}`),
      );
    }),
  );
  $('records').replaceChildren(grid);
}

function renderLogs(rows) {
  $('summary').textContent = `${rows.length} nhật ký thao tác Admin gần nhất`;
  const table = el(
    'div',
    {className: 'table-wrap'},
    el(
      'table',
      {},
      el(
        'thead',
        {},
        el(
          'tr',
          {},
          el('th', {}, 'Thời gian'),
          el('th', {}, 'Hành động'),
          el('th', {}, 'Admin thực hiện'),
          el('th', {}, 'Target User'),
        ),
      ),
      el(
        'tbody',
        {},
        rows.map(l =>
          el(
            'tr',
            {},
            el('td', {className: 'mono'}, fmtDate(l.created_at)),
            el('td', {}, el('span', {className: 'badge badge-admin'}, l.action)),
            el('td', {className: 'mono'}, shortId(l.admin_id)),
            el(
              'td',
              {},
              l.target_user_id
                ? el(
                    'button',
                    {
                      type: 'button',
                      className: 'btn-sm mono',
                      onClick: () => openUserDetailModal(l.target_user_id),
                    },
                    shortId(l.target_user_id),
                  )
                : el('span', {className: 'mono'}, '—'),
            ),
          ),
        ),
      ),
    ),
  );
  $('records').replaceChildren(table);
}

async function render() {
  $('heading').textContent = sections[section] || section;
  for (const btn of $('navigation').querySelectorAll('button')) {
    btn.classList.toggle('active', btn.dataset.key === section);
  }
  const data = await rpc(section, {search: $('search').query.value.trim()});
  if (section === 'dashboard') {
    renderDashboard(data || {});
    return;
  }
  const rows = Array.isArray(data) ? data : [data];
  if (section === 'users') renderUsers(rows);
  else if (section === 'devices') renderDevices(rows);
  else if (section === 'entitlements') renderEntitlements(rows);
  else if (section === 'flags') renderFlags(rows);
  else if (section === 'logs') renderLogs(rows);
}

function switchSection(next) {
  section = next;
  run(render);
}

$('fill-staging').onclick = () => {
  $('url').value = 'https://jsxxxbspjmpbaomotgcj.supabase.co';
  $('key').focus();
};

$('back-connect').onclick = () => {
  $('login').hidden = true;
  $('connect').hidden = false;
};

$('open-password-btn').onclick = () => {
  const drawer = $('password-drawer');
  drawer.open = true;
  drawer.scrollIntoView({behavior: 'smooth'});
};

$('refresh-btn').onclick = () => run(render);

$('connect').onsubmit = e => {
  e.preventDefault();
  run(async () => {
    const uri = new URL($('url').value.trim());
    if (uri.protocol !== 'https:' && uri.hostname !== '127.0.0.1') {
      throw Error('Cần HTTPS cho kết nối Supabase');
    }
    client = createClient(uri.href, $('key').value.trim(), {
      auth: {persistSession: false},
    });
    $('login').hidden = false;
    $('connect').hidden = true;
  });
};

$('login').onsubmit = e => {
  e.preventDefault();
  run(async () => {
    const {data, error} = await client.auth.signInWithPassword({
      email: e.target.email.value.trim(),
      password: e.target.password.value,
    });
    e.target.password.value = '';
    if (error) throw Error('Đăng nhập thất bại. Kiểm tra lại email và mật khẩu.');
    currentAdminId = data?.user?.id || null;
    try {
      await rpc('dashboard');
    } catch (err) {
      await client.auth.signOut();
      throw err;
    }
    $('panel').hidden = false;
    $('login').hidden = true;
    $('logout').hidden = false;
    $('open-password-btn').hidden = false;
    await render();
  });
};

for (const [key, label] of Object.entries(sections)) {
  const button = el(
    'button',
    {
      type: 'button',
      className: `nav-tab ${key === section ? 'active' : ''}`,
      'data-key': key,
      onClick: () => switchSection(key),
    },
    label,
  );
  $('navigation').append(button);
}

$('search').onsubmit = e => {
  e.preventDefault();
  if (section !== 'users') section = 'users';
  run(render);
};

$('search').query.oninput = () => {
  clearTimeout(searchDebounce);
  searchDebounce = setTimeout(() => {
    if (section === 'users') run(render);
  }, 320);
};

$('action').onsubmit = e => {
  e.preventDefault();
  run(async () => {
    const payload = Object.fromEntries(new FormData(e.target));
    const action = payload.action;
    delete payload.action;
    payload.enabled = e.target.enabled.checked;
    if (payload.expires_at) {
      payload.expires_at = new Date(payload.expires_at).toISOString();
    }
    if (action !== 'details' && !confirm('Xác nhận thực hiện thay đổi quản trị?')) return;
    const res = await rpc(action, payload);
    $('detail').hidden = false;
    $('detail').textContent = JSON.stringify(res, null, 2);
    await render();
  });
};

$('password').onsubmit = e => {
  e.preventDefault();
  run(async () => {
    const {error} = await client.auth.updateUser({
      password: e.target.password.value,
    });
    e.target.reset();
    if (error) throw Error('Không đổi được mật khẩu');
  });
};

$('logout').onclick = () =>
  run(async () => {
    await client.auth.signOut();
    currentAdminId = null;
    $('panel').hidden = true;
    $('logout').hidden = true;
    $('open-password-btn').hidden = true;
    $('login').hidden = false;
    $('records').replaceChildren();
    $('detail').textContent = '';
    $('detail').hidden = true;
    closeModal();
  });
