'use strict';
/**
 * Fstool 授权服务（零依赖，单文件）
 *
 * 功能：
 *   - 卡密激活（设备绑定，自动开始计时）
 *   - 账号注册（用卡密开通）/ 账号登录
 *   - 授权查询（客户端每次启动 / 定期校验）
 *   - 管理端：批量生成卡密、封禁、解绑设备
 *
 * 运行：
 *   ADMIN_TOKEN=xxx JWT_SECRET=yyy node server.js
 *
 * 环境变量：
 *   PORT         监听端口，默认 8787
 *   DATA_FILE    数据文件路径，默认 ./data.json
 *   ADMIN_TOKEN  管理端口令（必改）
 *   JWT_SECRET   令牌签名密钥（必改）
 *   TOKEN_TTL_DAYS 令牌有效期天数，默认 30
 */

const http = require('node:http');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const path = require('node:path');
const crypto = require('node:crypto');

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || '0.0.0.0';
const DATA_FILE = process.env.DATA_FILE || path.join(__dirname, 'data.json');
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || '';
const JWT_SECRET = process.env.JWT_SECRET || '';
const TOKEN_TTL_DAYS = Number(process.env.TOKEN_TTL_DAYS || 30);

if (!ADMIN_TOKEN || !JWT_SECRET) {
  console.error('[fatal] 必须设置 ADMIN_TOKEN 和 JWT_SECRET 环境变量');
  process.exit(1);
}

const DAY = 86400000;

// ---------------------------------------------------------------- 存储
let db = { keys: {}, users: {} };

function loadDb() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      const raw = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
      db.keys = raw.keys || {};
      db.users = raw.users || {};
    }
  } catch (error) {
    console.error('[warn] 数据文件损坏，使用空库:', error.message);
  }
}

let saveTimer = null;
function saveDb() {
  if (saveTimer) return;
  saveTimer = setTimeout(async () => {
    saveTimer = null;
    try {
      const tmp = `${DATA_FILE}.tmp`;
      await fsp.writeFile(tmp, JSON.stringify(db, null, 2), 'utf8');
      await fsp.rename(tmp, DATA_FILE);
    } catch (error) {
      console.error('[error] 写入失败:', error.message);
    }
  }, 80);
}

// ---------------------------------------------------------------- 工具
function httpError(status, code, message) {
  const error = new Error(message || code);
  error.status = status;
  error.code = code;
  return error;
}

function b64url(input) {
  return Buffer.from(input).toString('base64url');
}

function signToken(payload) {
  const header = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64url(JSON.stringify(payload));
  const sig = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64url');
  return `${header}.${body}.${sig}`;
}

function verifyToken(token) {
  const parts = String(token || '').split('.');
  if (parts.length !== 3) return null;
  const [header, body, sig] = parts;
  const expect = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(`${header}.${body}`)
    .digest('base64url');
  if (expect.length !== sig.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(expect), Buffer.from(sig))) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (payload.exp && Date.now() > payload.exp) return null;
    return payload;
  } catch {
    return null;
  }
}

function hashPassword(password, salt) {
  return crypto.scryptSync(String(password), salt, 32).toString('hex');
}

function normalizeKey(key) {
  return String(key || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
}

function randomKey() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const groups = [];
  for (let g = 0; g < 3; g += 1) {
    let chunk = '';
    for (let i = 0; i < 4; i += 1) {
      chunk += alphabet[crypto.randomInt(0, alphabet.length)];
    }
    groups.push(chunk);
  }
  return `FST-${groups.join('-')}`;
}

// 卡密在库里带连字符（FST-XXXX-XXXX-XXXX），用户输入可能有空格/小写，
// 所以统一用「规范化后的 key」建索引，避免去掉连字符后查不到。
let keyIndex = null;

function indexKey(rawKey) {
  if (keyIndex) keyIndex.set(normalizeKey(rawKey), rawKey);
}

function findKeyRecord(rawKey) {
  const norm = normalizeKey(rawKey);
  if (!norm) return null;
  if (!keyIndex) {
    keyIndex = new Map();
    for (const key of Object.keys(db.keys)) {
      keyIndex.set(normalizeKey(key), key);
    }
  }
  const real = keyIndex.get(norm);
  return real ? db.keys[real] : null;
}

function keyRecord(rawKey) {
  const rec = findKeyRecord(rawKey);
  if (rec && !rec.expiresAt && rec.activatedAt) {
    rec.expiresAt = rec.activatedAt + rec.days * DAY;
  }
  return rec;
}

function remainingDays(expiresAt) {
  if (!expiresAt) return 0;
  return Math.max(0, Math.ceil((expiresAt - Date.now()) / DAY));
}

// ---------------------------------------------------------------- 授权判定
function resolveLicense(payload) {
  if (payload.t === 'key') {
    const rec = keyRecord(payload.sub);
    if (!rec) return { valid: false, reason: 'key_not_found' };
    if (rec.revoked) return { valid: false, reason: 'revoked' };
    if (rec.deviceId && rec.deviceId !== payload.dev) {
      return { valid: false, reason: 'device_mismatch' };
    }
    if (!rec.expiresAt || Date.now() > rec.expiresAt) {
      return { valid: false, reason: 'expired' };
    }
    return {
      valid: true,
      plan: rec.plan || 'standard',
      expiresAt: rec.expiresAt,
      remainingDays: remainingDays(rec.expiresAt),
    };
  }

  if (payload.t === 'user') {
    const user = db.users[payload.sub];
    if (!user) return { valid: false, reason: 'user_not_found' };
    if (user.banned) return { valid: false, reason: 'banned' };
    if (user.deviceId && user.deviceId !== payload.dev) {
      return { valid: false, reason: 'device_mismatch' };
    }
    // 已注册但没兑换时长
    if (!user.expiresAt) {
      return {
        valid: false,
        reason: 'no_license',
        plan: user.plan || 'free',
        expiresAt: null,
        remainingDays: 0,
        username: user.username,
        nickname: user.nickname || user.username,
        bio: user.bio || '',
      };
    }
    if (Date.now() > user.expiresAt) {
      return {
        valid: false,
        reason: 'expired',
        plan: user.plan || 'standard',
        expiresAt: user.expiresAt,
        remainingDays: 0,
        username: user.username,
        nickname: user.nickname || user.username,
        bio: user.bio || '',
      };
    }
    return {
      valid: true,
      plan: user.plan || 'standard',
      expiresAt: user.expiresAt,
      remainingDays: remainingDays(user.expiresAt),
      username: user.username,
      nickname: user.nickname || user.username,
      bio: user.bio || '',
    };
  }

  return { valid: false, reason: 'bad_token' };
}

// ---------------------------------------------------------------- 业务
function issueToken(type, subject, device) {
  return signToken({
    t: type,
    sub: subject,
    dev: device,
    iat: Date.now(),
    exp: Date.now() + TOKEN_TTL_DAYS * DAY,
  });
}

function activateKey(rawKey, device, deviceName) {
  const key = normalizeKey(rawKey);
  if (!key) throw httpError(400, 'key_required', '请填写卡密');
  if (!device) throw httpError(400, 'device_required', '缺少设备标识');

  const rec = findKeyRecord(rawKey);
  if (!rec) throw httpError(404, 'key_not_found', '卡密不存在');
  if (rec.revoked) throw httpError(403, 'revoked', '该卡密已被封禁');

  if (!rec.activatedAt) {
    rec.activatedAt = Date.now();
    rec.expiresAt = rec.activatedAt + rec.days * DAY;
    rec.deviceId = device;
    rec.deviceName = deviceName || '';
  } else if (rec.deviceId && rec.deviceId !== device) {
    throw httpError(409, 'device_bound', '该卡密已绑定其他设备，请联系管理员解绑');
  } else if (!rec.deviceId) {
    rec.deviceId = device;
    rec.deviceName = deviceName || '';
  }

  if (Date.now() > rec.expiresAt) throw httpError(403, 'expired', '卡密已过期');

  saveDb();
  return {
    token: issueToken('key', rec.key, device),
    plan: rec.plan || 'standard',
    expiresAt: rec.expiresAt,
    remainingDays: remainingDays(rec.expiresAt),
  };
}

function registerUser({ key: rawKey, username, password, device, deviceName }) {
  const key = normalizeKey(rawKey);
  const name = String(username || '').trim();
  if (!key) throw httpError(400, 'key_required', '请填写卡密');
  if (name.length < 3) throw httpError(400, 'username_short', '账号至少 3 个字符');
  if (String(password || '').length < 6) {
    throw httpError(400, 'password_short', '密码至少 6 位');
  }
  if (!device) throw httpError(400, 'device_required', '缺少设备标识');

  const rec = findKeyRecord(rawKey);
  if (!rec) throw httpError(404, 'key_not_found', '卡密不存在');
  if (rec.revoked) throw httpError(403, 'revoked', '该卡密已被封禁');
  if (rec.activatedAt || rec.user) {
    throw httpError(409, 'key_used', '该卡密已被使用');
  }
  if (db.users[name]) throw httpError(409, 'username_taken', '账号已存在');

  const now = Date.now();
  const salt = crypto.randomBytes(16).toString('hex');
  db.users[name] = {
    username: name,
    salt,
    hash: hashPassword(password, salt),
    createdAt: now,
    expiresAt: now + rec.days * DAY,
    plan: rec.plan || 'standard',
    deviceId: device,
    deviceName: deviceName || '',
    banned: false,
  };

  rec.activatedAt = now;
  rec.expiresAt = now + rec.days * DAY;
  rec.deviceId = device;
  rec.deviceName = deviceName || '';
  rec.user = name;

  saveDb();
  return {
    token: issueToken('user', name, device),
    plan: db.users[name].plan,
    expiresAt: db.users[name].expiresAt,
    remainingDays: remainingDays(db.users[name].expiresAt),
  };
}

function loginUser({ username, password, device, deviceName }) {
  const name = String(username || '').trim();
  const user = db.users[name];
  if (!user) throw httpError(401, 'bad_credentials', '账号或密码错误');
  if (user.banned) throw httpError(403, 'banned', '该账号已被封禁');
  if (!device) throw httpError(400, 'device_required', '缺少设备标识');

  const hash = hashPassword(password || '', user.salt);
  const ok =
    hash.length === user.hash.length &&
    crypto.timingSafeEqual(Buffer.from(hash), Buffer.from(user.hash));
  if (!ok) throw httpError(401, 'bad_credentials', '账号或密码错误');

  if (user.deviceId && user.deviceId !== device) {
    // 首次换设备自动绑定，之后需要管理员解绑（可在管理端 unbind）
    throw httpError(409, 'device_bound', '账号已绑定其他设备，请联系管理员解绑');
  }
  if (!user.deviceId) {
    user.deviceId = device;
    user.deviceName = deviceName || '';
  }
  if (!user.expiresAt || Date.now() > user.expiresAt) {
    throw httpError(403, 'expired', '账号已到期，请续费');
  }

  saveDb();
  return {
    token: issueToken('user', name, device),
    plan: user.plan || 'standard',
    expiresAt: user.expiresAt,
    remainingDays: remainingDays(user.expiresAt),
  };
}

// ---------------------------------------------------------------- 限流
const buckets = new Map();
function rateLimit(ip) {
  const now = Date.now();
  const bucket = buckets.get(ip);
  if (!bucket || now > bucket.resetAt) {
    buckets.set(ip, { count: 1, resetAt: now + 60000 });
    return true;
  }
  bucket.count += 1;
  if (bucket.count % 500 === 0) {
    for (const [key, value] of buckets) {
      if (now > value.resetAt) buckets.delete(key);
    }
  }
  return bucket.count <= 120;
}

// ---------------------------------------------------------------- HTTP
function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 64 * 1024) {
        reject(httpError(413, 'too_large', '请求体过大'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(httpError(400, 'bad_json', '请求格式错误'));
      }
    });
    req.on('error', reject);
  });
}

function send(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'content-length': Buffer.byteLength(body),
  });
  res.end(body);
}

function bearer(req) {
  const header = req.headers.authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1] : null;
}

// ---------------------------------------------------------------- 网页后台
const ADMIN_COOKIE = 'fstool_admin';
let adminFlash = '';
let lastGenerated = [];

function parseCookies(req) {
  const out = {};
  const raw = req.headers.cookie || '';
  raw.split(';').forEach((part) => {
    const index = part.indexOf('=');
    if (index > 0) {
      out[part.slice(0, index).trim()] = decodeURIComponent(
        part.slice(index + 1).trim(),
      );
    }
  });
  return out;
}

function isAdmin(req) {
  return parseCookies(req)[ADMIN_COOKIE] === ADMIN_TOKEN;
}

function readForm(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > 64 * 1024) {
        reject(httpError(413, 'too_large', '请求体过大'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => {
      const text = Buffer.concat(chunks).toString('utf8');
      const out = {};
      text.split('&').forEach((pair) => {
        if (!pair) return;
        const index = pair.indexOf('=');
        const key = decodeURIComponent(
          (index >= 0 ? pair.slice(0, index) : pair).replace(/\+/g, ' '),
        );
        const value =
          index >= 0
            ? decodeURIComponent(pair.slice(index + 1).replace(/\+/g, ' '))
            : '';
        out[key] = value;
      });
      resolve(out);
    });
    req.on('error', reject);
  });
}

function sendHtml(res, status, html) {
  res.writeHead(status, {
    'content-type': 'text/html; charset=utf-8',
    'cache-control': 'no-store',
  });
  res.end(html);
}

function redirect(res, location) {
  res.writeHead(302, { location });
  res.end();
}

function esc(value) {
  return String(value == null ? '' : value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const ADMIN_CSS = `
*{box-sizing:border-box}
body{margin:0;background:#0d1117;color:#e6edf3;font:14px/1.6 -apple-system,"Segoe UI","Microsoft YaHei",sans-serif}
a{color:#58a6ff;text-decoration:none}
.wrap{max-width:1080px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:20px;margin:0 0 4px}
h2{font-size:15px;margin:28px 0 10px;color:#9aa7b4;font-weight:600}
.card{background:#161b22;border:1px solid #232c38;border-radius:14px;padding:16px}
.row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
input,select{background:#0d1117;border:1px solid #2b3644;border-radius:9px;color:#e6edf3;padding:9px 11px;font-size:14px;outline:none}
input:focus,select:focus{border-color:#4b93ff}
button{background:#1f6feb;border:0;border-radius:9px;color:#fff;padding:9px 16px;font-size:14px;cursor:pointer}
button.ghost{background:#21262d;color:#c9d1d9}
button.warn{background:#8b2c2c}
button.small{padding:5px 10px;font-size:12px;border-radius:7px}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:9px 8px;border-bottom:1px solid #21262d;white-space:nowrap}
th{color:#8b949e;font-weight:500}
tr:hover td{background:#12171e}
.badge{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11px}
.ok{background:#12341f;color:#3fb950}
.use{background:#12243a;color:#58a6ff}
.off{background:#3a1d1d;color:#f85149}
.idle{background:#21262d;color:#8b949e}
.mono{font-family:ui-monospace,Consolas,monospace}
.keys{width:100%;height:120px;background:#0d1117;border:1px solid #2b3644;border-radius:10px;color:#7ee787;font-family:ui-monospace,Consolas,monospace;font-size:13px;padding:10px;resize:vertical}
.flash{background:#12261a;border:1px solid #1f6f3f;color:#3fb950;padding:9px 12px;border-radius:10px;margin:14px 0}
.err{background:#2a1414;border:1px solid #5a2323;color:#f85149;padding:9px 12px;border-radius:10px;margin:14px 0}
.muted{color:#8b949e;font-size:12px}
`;

function adminLoginPage(error) {
  return `<!doctype html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fstool 授权后台</title><style>${ADMIN_CSS}</style></head><body>
<div class="wrap" style="max-width:380px;padding-top:80px">
<h1>Fstool 授权后台</h1>
<p class="muted">输入管理口令</p>
${error ? `<div class="err">${esc(error)}</div>` : ''}
<form method="post" action="/admin/login" class="card">
  <div class="row">
    <input type="password" name="token" placeholder="ADMIN_TOKEN" style="flex:1" autofocus>
    <button type="submit">登录</button>
  </div>
</form>
</div></body></html>`;
}

function adminPage(keys, users, flash, generated) {
  const keyRows = keys
    .map((rec) => {
      let badge = '<span class="badge idle">未使用</span>';
      if (rec.revoked) badge = '<span class="badge off">已封禁</span>';
      else if (rec.activatedAt) {
        badge =
          rec.expiresAt && rec.expiresAt < Date.now()
            ? '<span class="badge off">已过期</span>'
            : '<span class="badge use">使用中</span>';
      }
      const left = rec.expiresAt ? remainingDays(rec.expiresAt) : 0;
      return `<tr>
<td class="mono">${esc(rec.key)}</td>
<td>${badge}</td>
<td>${esc(rec.plan)}</td>
<td>${rec.days}</td>
<td>${rec.activatedAt ? left + ' 天' : '-'}</td>
<td class="muted">${esc(rec.deviceName || rec.deviceId || '-')}</td>
<td>
  <form method="post" action="/admin/action" style="display:inline">
    <input type="hidden" name="key" value="${esc(rec.key)}">
    <input type="hidden" name="action" value="${rec.revoked ? 'unrevoke' : 'revoke'}">
    <button class="small ${rec.revoked ? 'ghost' : 'warn'}">${rec.revoked ? '解封' : '封禁'}</button>
  </form>
  <form method="post" action="/admin/action" style="display:inline">
    <input type="hidden" name="key" value="${esc(rec.key)}">
    <input type="hidden" name="action" value="unbind">
    <button class="small ghost">解绑</button>
  </form>
  <form method="post" action="/admin/action" style="display:inline">
    <input type="hidden" name="key" value="${esc(rec.key)}">
    <input type="hidden" name="action" value="extend">
    <button class="small ghost">+30天</button>
  </form>
  <form method="post" action="/admin/delete-key" style="display:inline"
        onsubmit="return confirm('确定删除这张卡密？删除后无法恢复')">
    <input type="hidden" name="key" value="${esc(rec.key)}">
    <button class="small warn">删除</button>
  </form>
</td></tr>`;
    })
    .join('');

  const userRows = users
    .map((user) => `<tr>
<td class="mono">${esc(user.username)}</td>
<td>${esc(user.nickname || '-')}</td>
<td>${user.expiresAt ? remainingDays(user.expiresAt) + ' 天' : '<span class="muted">未兑换</span>'}</td>
<td class="muted">${esc(user.deviceName || user.deviceId || '-')}</td>
<td>${user.banned ? '<span class="badge off">封禁</span>' : '<span class="badge ok">正常</span>'}</td>
<td>
  <form method="post" action="/admin/delete-user" style="display:inline"
        onsubmit="return confirm('确定删除该用户？其卡密不会被删除')">
    <input type="hidden" name="username" value="${esc(user.username)}">
    <button class="small warn">删除</button>
  </form>
</td>
</tr>`)
    .join('');

  return `<!doctype html><html lang="zh"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Fstool 授权后台</title><style>${ADMIN_CSS}</style></head><body>
<div class="wrap">
<h1>Fstool 授权后台</h1>
<p class="muted">卡密 ${keys.length} 条 · 账号 ${users.length} 个</p>
${flash ? `<div class="flash">${esc(flash)}</div>` : ''}

<h2>生成卡密</h2>
<form method="post" action="/admin/gen" class="card row">
  <label class="muted">数量</label>
  <input type="number" name="count" value="10" min="1" max="200" style="width:90px">
  <label class="muted">天数</label>
  <input type="number" name="days" value="30" min="1" max="3650" style="width:90px">
  <label class="muted">套餐</label>
  <input name="plan" value="standard" style="width:130px">
  <button type="submit">生成</button>
</form>

${generated.length ? `<h2>刚生成的卡密</h2><div class="card">
  <textarea class="keys" id="gen" readonly>${generated.join('\n')}</textarea>
  <div class="row" style="margin-top:10px">
    <button type="button" class="ghost small" onclick="const t=document.getElementById('gen');t.select();document.execCommand('copy')">复制全部</button>
    <span class="muted">共 ${generated.length} 张，关掉页面后仍可在下方列表查到</span>
  </div>
</div>` : ''}

<h2>卡密列表</h2>
<div class="card" style="overflow:auto">
<table><thead><tr>
<th>卡密</th><th>状态</th><th>套餐</th><th>天数</th><th>剩余</th><th>设备</th><th>操作</th>
</tr></thead><tbody>${keyRows || '<tr><td colspan="7" class="muted">还没有卡密，先在上面生成</td></tr>'}</tbody></table>
</div>

<h2>账号列表</h2>
<div class="card" style="overflow-x:auto">
<table><thead><tr><th>账号</th><th>昵称</th><th>剩余</th><th>设备</th><th>状态</th><th>操作</th></tr></thead>
<tbody>${userRows || '<tr><td colspan="5" class="muted">还没有注册用户</td></tr>'}</tbody></table>
</div>

<p class="muted" style="margin-top:24px">Fstool License Admin · 请勿把此页面地址和管理口令发给他人</p>
</div></body></html>`;
}

async function route(req, res) {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  const p = url.pathname.replace(/\/+$/, '') || '/';

  if (req.method === 'GET' && p === '/') {
    return send(res, 200, {
      name: 'fstool-license',
      ok: true,
      keys: Object.keys(db.keys).length,
      users: Object.keys(db.users).length,
    });
  }

  // ------------------------------------------------ 网页后台 /admin
  if (p === '/admin' || p.startsWith('/admin/')) {
    if (req.method === 'POST' && p === '/admin/login') {
      const form = await readForm(req);
      if ((form.token || '') === ADMIN_TOKEN) {
        res.writeHead(302, {
          'set-cookie': `${ADMIN_COOKIE}=${encodeURIComponent(ADMIN_TOKEN)}; HttpOnly; Path=/; SameSite=Lax; Max-Age=604800`,
          location: '/admin',
        });
        return res.end();
      }
      return sendHtml(res, 401, adminLoginPage('口令错误'));
    }

    if (!isAdmin(req)) return sendHtml(res, 200, adminLoginPage(''));

    if (req.method === 'POST' && p === '/admin/gen') {
      const form = await readForm(req);
      const count = Math.min(Math.max(Number(form.count) || 10, 1), 200);
      const days = Math.min(Math.max(Number(form.days) || 30, 1), 3650);
      const plan = String(form.plan || 'standard').slice(0, 24);
      const created = [];
      for (let i = 0; i < count; i += 1) {
        let key = randomKey();
        while (db.keys[key]) key = randomKey();
        db.keys[key] = {
          key,
          plan,
          days,
          createdAt: Date.now(),
          activatedAt: null,
          expiresAt: null,
          deviceId: null,
          deviceName: null,
          revoked: false,
          user: null,
        };
        indexKey(key);
        created.push(key);
      }
      saveDb();
      lastGenerated = created;
      adminFlash = `已生成 ${created.length} 张 ${days} 天卡（${plan}）`;
      return redirect(res, '/admin');
    }

    if (req.method === 'POST' && p === '/admin/action') {
      const form = await readForm(req);
      const rec = findKeyRecord(form.key);
      const action = String(form.action || '');
      if (rec) {
        if (action === 'revoke') {
          rec.revoked = true;
          adminFlash = `已封禁 ${rec.key}`;
        } else if (action === 'unrevoke') {
          rec.revoked = false;
          adminFlash = `已解封 ${rec.key}`;
        } else if (action === 'unbind') {
          rec.deviceId = null;
          rec.deviceName = null;
          adminFlash = `已解绑 ${rec.key}`;
        } else if (action === 'extend') {
          const base = rec.expiresAt || Date.now();
          rec.expiresAt = base + 30 * DAY;
          adminFlash = `已为 ${rec.key} 续期 30 天`;
        }
        saveDb();
      }
      return redirect(res, '/admin');
    }

    if (req.method === 'POST' && p === '/admin/delete-key') {
      const form = await readForm(req);
      const rec = findKeyRecord(form.key);
      if (rec) {
        delete db.keys[rec.key];
        if (keyIndex) keyIndex.delete(normalizeKey(rec.key));
        saveDb();
        adminFlash = `已删除卡密 ${rec.key}`;
      }
      return redirect(res, '/admin');
    }

    if (req.method === 'POST' && p === '/admin/delete-user') {
      const form = await readForm(req);
      const username = String(form.username || '').trim();
      if (db.users[username]) {
        delete db.users[username];
        saveDb();
        adminFlash = `已删除用户 ${username}`;
      }
      return redirect(res, '/admin');
    }

    const keyList = Object.values(db.keys)
      .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
      .slice(0, 300);
    const userList = Object.values(db.users).slice(0, 200);
    const html = adminPage(keyList, userList, adminFlash, lastGenerated);
    adminFlash = '';
    lastGenerated = [];
    return sendHtml(res, 200, html);
  }

  if (req.method === 'POST' && (p === '/api/activate' || p === '/api/login' || p === '/api/register')) {
    const body = await readBody(req);
    const device = String(body.device || '').trim();
    const deviceName = String(body.deviceName || '').slice(0, 64);
    let result;
    if (p === '/api/activate') {
      result = activateKey(body.key, device, deviceName);
    } else if (p === '/api/login') {
      result = loginUser({
        username: body.username,
        password: body.password,
        device,
        deviceName,
      });
    } else {
      result = registerUser({
        key: body.key,
        username: body.username,
        password: body.password,
        device,
        deviceName,
      });
    }
    return send(res, 200, { ok: true, ...result });
  }

  if (req.method === 'GET' && (p === '/api/license' || p === '/api/heartbeat')) {
    const payload = verifyToken(bearer(req));
    if (!payload) return send(res, 401, { ok: false, error: 'bad_token', message: '登录状态失效，请重新激活' });
    const state = resolveLicense(payload);
    if (!state.valid) {
      // no_license 不是错误：用户已注册，只是还没兑换时长
      if (state.reason === 'no_license') {
        return send(res, 200, {
          ok: true,
          valid: false,
          ...state,
          message: reasonText(state.reason),
          serverTime: Date.now(),
        });
      }
      return send(res, 403, {
        ok: false,
        valid: false,
        error: state.reason,
        message: reasonText(state.reason),
      });
    }
    return send(res, 200, { ok: true, ...state, serverTime: Date.now() });
  }

  // ------------------------------------------------ 账号（注册 / 兑换 / 资料）
  if (req.method === 'POST' && p === '/api/signup') {
    const body = await readBody(req);
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    const device = String(body.device || '').trim();

    if (username.length < 2) {
      return send(res, 400, { ok: false, error: 'username_short', message: '昵称至少 2 个字符' });
    }
    if (password.length < 6) {
      return send(res, 400, { ok: false, error: 'password_short', message: '密码至少 6 位' });
    }
    if (!device) {
      return send(res, 400, { ok: false, error: 'device_required', message: '缺少设备标识' });
    }
    if (db.users[username]) {
      return send(res, 409, { ok: false, error: 'username_taken', message: '这个昵称已被注册，换一个' });
    }

    const salt = crypto.randomBytes(16).toString('hex');
    db.users[username] = {
      username,
      salt,
      hash: hashPassword(password, salt),
      createdAt: Date.now(),
      expiresAt: null,
      plan: 'free',
      deviceId: device,
      deviceName: String(body.deviceName || '').slice(0, 64),
      nickname: username,
      bio: '',
      banned: false,
    };
    saveDb();

    return send(res, 200, {
      ok: true,
      token: issueToken('user', username, device),
      plan: 'free',
      expiresAt: null,
      remainingDays: 0,
      username,
      nickname: username,
      bio: '',
    });
  }

  if (req.method === 'POST' && p === '/api/quick-register') {
    const body = await readBody(req);
    const device = String(body.device || '').trim();
    if (!device) {
      return send(res, 400, { ok: false, error: 'device_required', message: '缺少设备标识' });
    }
    const nickname = String(body.nickname || '').trim().slice(0, 24);

    let user = Object.values(db.users).find((item) => item.deviceId === device);
    if (!user) {
      const salt = crypto.randomBytes(16).toString('hex');
      const username = `u${crypto.randomBytes(4).toString('hex')}`;
      const password = crypto.randomBytes(16).toString('hex');
      user = {
        username,
        salt,
        hash: hashPassword(password, salt),
        createdAt: Date.now(),
        expiresAt: null,
        plan: 'free',
        deviceId: device,
        deviceName: String(body.deviceName || '').slice(0, 64),
        nickname: nickname || username,
        bio: '',
        banned: false,
      };
      db.users[username] = user;
    } else if (nickname && user.nickname !== nickname) {
      user.nickname = nickname;
    }
    saveDb();

    return send(res, 200, {
      ok: true,
      token: issueToken('user', user.username, device),
      plan: user.plan,
      expiresAt: user.expiresAt,
      remainingDays: remainingDays(user.expiresAt),
      username: user.username,
      nickname: user.nickname || user.username,
      bio: user.bio || '',
    });
  }

  if (req.method === 'POST' && p === '/api/redeem') {
    const payload = verifyToken(bearer(req));
    const user = payload && payload.t === 'user' ? db.users[payload.sub] : null;
    if (!user) {
      return send(res, 401, { ok: false, error: 'bad_token', message: '请先注册或登录' });
    }
    if (user.banned) {
      return send(res, 403, { ok: false, error: 'banned', message: '账号已被封禁' });
    }

    const body = await readBody(req);
    const rec = findKeyRecord(body.key);
    if (!rec) return send(res, 404, { ok: false, error: 'key_not_found', message: '卡密不存在' });
    if (rec.revoked) return send(res, 403, { ok: false, error: 'revoked', message: '该卡密已被封禁' });
    if (rec.activatedAt || rec.user) {
      if (rec.user !== user.username) {
        return send(res, 409, { ok: false, error: 'key_used', message: '该卡密已被其他账号使用' });
      }
    }

    const now = Date.now();
    const base = user.expiresAt && user.expiresAt > now ? user.expiresAt : now;
    user.expiresAt = base + rec.days * DAY;
    user.plan = rec.plan || user.plan;
    rec.activatedAt = rec.activatedAt || now;
    rec.expiresAt = user.expiresAt;
    rec.deviceId = user.deviceId;
    rec.deviceName = user.deviceName;
    rec.user = user.username;
    saveDb();

    return send(res, 200, {
      ok: true,
      plan: user.plan,
      expiresAt: user.expiresAt,
      remainingDays: remainingDays(user.expiresAt),
    });
  }

  if (req.method === 'POST' && p === '/api/profile') {
    const payload = verifyToken(bearer(req));
    const user = payload && payload.t === 'user' ? db.users[payload.sub] : null;
    if (!user) {
      return send(res, 401, { ok: false, error: 'bad_token', message: '请先注册或登录' });
    }
    const body = await readBody(req);
    if (typeof body.nickname === 'string') {
      user.nickname = body.nickname.trim().slice(0, 24) || user.username;
    }
    if (typeof body.bio === 'string') {
      user.bio = body.bio.trim().slice(0, 120);
    }
    saveDb();
    return send(res, 200, {
      ok: true,
      nickname: user.nickname || user.username,
      bio: user.bio || '',
    });
  }

  // ------------------------------------------------ 管理端
  if (p.startsWith('/api/admin/')) {
    if ((req.headers['x-admin-token'] || '') !== ADMIN_TOKEN) {
      return send(res, 401, { ok: false, error: 'admin_denied', message: '管理口令错误' });
    }

    if (req.method === 'POST' && p === '/api/admin/keys') {
      const body = await readBody(req);
      const count = Math.min(Math.max(Number(body.count) || 10, 1), 200);
      const days = Math.min(Math.max(Number(body.days) || 30, 1), 3650);
      const plan = String(body.plan || 'standard').slice(0, 24);
      const created = [];
      for (let i = 0; i < count; i += 1) {
        const key = randomKey();
        if (db.keys[key]) {
          i -= 1;
          continue;
        }
        db.keys[key] = {
          key,
          plan,
          days,
          createdAt: Date.now(),
          activatedAt: null,
          expiresAt: null,
          deviceId: null,
          deviceName: null,
          revoked: false,
          user: null,
        };
        indexKey(key);
        created.push(key);
      }
      saveDb();
      return send(res, 200, { ok: true, keys: created, days, plan });
    }

    if (req.method === 'GET' && p === '/api/admin/keys') {
      const list = Object.values(db.keys)
        .sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0))
        .slice(0, 500)
        .map((rec) => ({
          key: rec.key,
          plan: rec.plan,
          days: rec.days,
          activated: Boolean(rec.activatedAt),
          expiresAt: rec.expiresAt,
          remainingDays: remainingDays(rec.expiresAt),
          deviceId: rec.deviceId,
          deviceName: rec.deviceName,
          revoked: Boolean(rec.revoked),
          user: rec.user,
        }));
      return send(res, 200, { ok: true, keys: list });
    }

    if (req.method === 'POST' && p === '/api/admin/revoke') {
      const body = await readBody(req);
      const rec = findKeyRecord(body.key);
      if (!rec) return send(res, 404, { ok: false, error: 'key_not_found' });
      rec.revoked = Boolean(body.revoked !== false);
      saveDb();
      return send(res, 200, { ok: true, key: rec.key, revoked: rec.revoked });
    }

    if (req.method === 'POST' && p === '/api/admin/unbind') {
      const body = await readBody(req);
      const target = String(body.key || body.username || '');
      const rec = findKeyRecord(target);
      if (rec) {
        rec.deviceId = null;
        rec.deviceName = null;
        saveDb();
        return send(res, 200, { ok: true, key: rec.key, deviceId: null });
      }
      const user = db.users[target];
      if (user) {
        user.deviceId = null;
        user.deviceName = null;
        saveDb();
        return send(res, 200, { ok: true, username: target, deviceId: null });
      }
      return send(res, 404, { ok: false, error: 'not_found' });
    }

    if (req.method === 'POST' && p === '/api/admin/delete-key') {
      const body = await readBody(req);
      const rec = findKeyRecord(body.key);
      if (!rec) return send(res, 404, { ok: false, error: 'key_not_found' });
      delete db.keys[rec.key];
      if (keyIndex) keyIndex.delete(normalizeKey(rec.key));
      saveDb();
      return send(res, 200, { ok: true, deleted: rec.key });
    }

    if (req.method === 'POST' && p === '/api/admin/delete-user') {
      const body = await readBody(req);
      const username = String(body.username || '').trim();
      if (!db.users[username]) {
        return send(res, 404, { ok: false, error: 'user_not_found' });
      }
      delete db.users[username];
      saveDb();
      return send(res, 200, { ok: true, deleted: username });
    }

    if (req.method === 'POST' && p === '/api/admin/extend') {
      const body = await readBody(req);
      const days = Math.min(Math.max(Number(body.days) || 30, 1), 3650);
      const rec = findKeyRecord(body.key);
      if (!rec) return send(res, 404, { ok: false, error: 'key_not_found' });
      const base = rec.expiresAt || Date.now();
      rec.expiresAt = base + days * DAY;
      saveDb();
      return send(res, 200, { ok: true, key: rec.key, expiresAt: rec.expiresAt });
    }
  }

  return send(res, 404, { ok: false, error: 'not_found' });
}

function reasonText(reason) {
  switch (reason) {
    case 'expired':
      return '授权已到期';
    case 'revoked':
      return '授权已被封禁';
    case 'device_mismatch':
      return '设备不匹配，请联系管理员解绑';
    case 'banned':
      return '账号已被封禁';
    case 'key_not_found':
      return '卡密不存在';
    case 'user_not_found':
      return '账号不存在';
    default:
      return '授权无效';
  }
}

loadDb();

const server = http.createServer(async (req, res) => {
  const ip = req.socket.remoteAddress || 'unknown';
  if (!rateLimit(ip)) return send(res, 429, { ok: false, error: 'rate_limited', message: '请求过于频繁' });
  try {
    await route(req, res);
  } catch (error) {
    const status = error.status || 500;
    if (status >= 500) console.error('[error]', error);
    send(res, status, {
      ok: false,
      error: error.code || 'server_error',
      message: error.message || '服务端错误',
    });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[fstool-license] listening on http://${HOST}:${PORT}`);
  console.log(`[fstool-license] data file: ${DATA_FILE}`);
  console.log(`[fstool-license] keys=${Object.keys(db.keys).length} users=${Object.keys(db.users).length}`);
});
