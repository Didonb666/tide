# Fstool 授权服务

零依赖 Node 服务（单文件），提供**卡密激活 / 账号登录 / 授权校验 / 管理端**。

## 一、启动

```bash
# 必须设置两个密钥，否则拒绝启动
ADMIN_TOKEN="换成你的管理口令" \
JWT_SECRET="换成一串随机字符串" \
PORT=8787 \
node server.js
```

数据存在同目录 `data.json`（原子写入，可直接备份/迁移）。

Docker：

```bash
docker run -d --name fstool-license \
  -p 8787:8787 \
  -e ADMIN_TOKEN="你的管理口令" \
  -e JWT_SECRET="你的签名密钥" \
  -v $(pwd)/data:/app/data \
  -e DATA_FILE=/app/data/data.json \
  node:20-alpine node /app/server.js
```

建议放在**有 HTTPS 的域名**后面（Nginx / Caddy / Cloudflare）。客户端默认禁止明文 HTTP。

## 二、生成卡密

```bash
curl -X POST http://127.0.0.1:8787/api/admin/keys \
  -H "x-admin-token: 你的管理口令" \
  -H "content-type: application/json" \
  -d '{"count":20,"days":30,"plan":"standard"}'
```

返回：

```json
{ "ok": true, "keys": ["FST-XXXX-XXXX-XXXX", "..."], "days": 30, "plan": "standard" }
```

其它管理接口：

| 接口 | 说明 |
|---|---|
| `GET /api/admin/keys` | 列出最近 500 条卡密及状态 |
| `POST /api/admin/revoke` `{"key":"FST-..."}` | 封禁/解封（`revoked:false` 解封） |
| `POST /api/admin/unbind` `{"key":"FST-..."}` 或 `{"username":"xxx"}` | 解绑设备（换机用） |
| `POST /api/admin/extend` `{"key":"FST-...","days":30}` | 续期 |

## 三、客户端接口

| 方法 | 路径 | 请求体 | 返回 |
|---|---|---|---|
| POST | `/api/activate` | `{key, device, deviceName}` | `{token, plan, expiresAt, remainingDays}` |
| POST | `/api/register` | `{key, username, password, device}` | 同上 |
| POST | `/api/login` | `{username, password, device}` | 同上 |
| GET | `/api/license` | 头 `Authorization: Bearer <token>` | `{valid, plan, expiresAt, remainingDays}` |

错误统一返回 `{ok:false, error:"code", message:"中文说明"}`。

## 四、安全要点

1. **务必改掉默认口令**，`ADMIN_TOKEN` / `JWT_SECRET` 用 32 位以上随机串；
2. 服务端只存 `scrypt` 后的密码哈希，不存明文；
3. 令牌里带设备 ID，换设备需管理端解绑；
4. 定期备份 `data.json`；
5. 客户端离线宽限 3 天，超过必须联网校验（防止改时间钻空子）。
