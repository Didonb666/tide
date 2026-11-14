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

function keyRecord(key) {
  const rec = db.keys[key];
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
    if (!user.expiresAt || Date.now() > user.expiresAt) {
      return { valid: false, reason: 'expired' };
    }
    return {
      valid: true,
      plan: user.plan || 'standard',
      expiresAt: user.expiresAt,
      remainingDays: remainingDays(user.expiresAt),
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

  const rec = db.keys[key];
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
    token: issueToken('key', key, device),
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

  const rec = db.keys[key];
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
      return send(res, 403, {
        ok: false,
        valid: false,
        error: state.reason,
        message: reasonText(state.reason),
      });
    }
    return send(res, 200, { ok: true, ...state, serverTime: Date.now() });
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
      const key = normalizeKey(body.key);
      const rec = db.keys[key];
      if (!rec) return send(res, 404, { ok: false, error: 'key_not_found' });
      rec.revoked = Boolean(body.revoked !== false);
      saveDb();
      return send(res, 200, { ok: true, key, revoked: rec.revoked });
    }

    if (req.method === 'POST' && p === '/api/admin/unbind') {
      const body = await readBody(req);
      const target = String(body.key || body.username || '');
      const key = normalizeKey(target);
      if (db.keys[key]) {
        db.keys[key].deviceId = null;
        db.keys[key].deviceName = null;
        saveDb();
        return send(res, 200, { ok: true, key, deviceId: null });
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

    if (req.method === 'POST' && p === '/api/admin/extend') {
      const body = await readBody(req);
      const key = normalizeKey(body.key);
      const days = Math.min(Math.max(Number(body.days) || 30, 1), 3650);
      const rec = db.keys[key];
      if (!rec) return send(res, 404, { ok: false, error: 'key_not_found' });
      const base = rec.expiresAt || Date.now();
      rec.expiresAt = base + days * DAY;
      saveDb();
      return send(res, 200, { ok: true, key, expiresAt: rec.expiresAt });
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
