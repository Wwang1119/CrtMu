# CrtMu 后端

Node.js / Express 服务，负责聊天、图片上传、作品分析、档案与开发会员状态。客户端经此服务访问 AI provider，模型密钥保留在服务端。

## 本地启动与检查

需要 Node.js 20+ 与 npm。在本目录执行：

```bash
cp .env.example .env
npm ci
npm run dev
```

Windows 命令提示符使用 `copy .env.example .env`。默认配置为 `DATA_STORE=json`、`UPLOAD_STORAGE=auto`、`AI_PROVIDER=mock`，监听 `127.0.0.1:3000`。mock 不需要模型密钥。

```bash
curl http://127.0.0.1:3000/health
npm test
node --check src/server.js
```

`npm run dev` 会读取 `.env` 并监听代码变化；`npm start` 只启动服务，需要部署环境预先注入变量，或使用 `node --env-file=.env src/server.js` 显式载入本地配置。

## 配置

完整字段见 [.env.example](.env.example)，具体读取逻辑见 [src/config.js](src/config.js)。

| 配置 | 用途 |
| --- | --- |
| `HOST` / `PORT` | 本地默认 `127.0.0.1` / `3000`；真机联调或容器内按需监听 `0.0.0.0` |
| `PUBLIC_BASE_URL` | 反向代理后的 HTTPS 公网地址，用于生成图片访问 URL |
| `DATA_STORE` | `json`、`cloudbase`、`mysql` |
| `UPLOAD_STORAGE` | `auto`、`local`、`cloudbase` |
| `AI_PROVIDER` | `mock` 或 `ark` |
| `ARK_API_KEY` | 真实模型调用密钥，仅放本地 `.env` 或服务端环境 |
| `ARK_TEXT_MODEL` / `ARK_VISION_MODEL` / `ARK_IMAGE_MODEL` | 文本、视觉与参考图生成模型配置；`ARK_MODEL` 为部分调用的兼容回退 |
| `ENABLE_RUNTIME_DEBUG` | 默认 `false`；临时启用 `/debug/runtime` 诊断，排查后关闭 |

### 业务与图片存储

- `DATA_STORE=json`：记录写入 `data/app-db.json`，适合本地开发。
- `DATA_STORE=cloudbase`：使用文档集合 `users`、`uploads`、`artworks`。部署前创建集合，配置 `CLOUDBASE_ENV_ID` 及运行环境所需凭证。
- `DATA_STORE=mysql`：使用 `DB_*` 变量，表结构见 [db/init.sql](db/init.sql)。
- `UPLOAD_STORAGE=auto`：在 CloudBase 业务存储模式下使用 CloudBase 云存储，其余模式使用本地 `uploads/`。
- `UPLOAD_STORAGE=cloudbase`：显式使用云存储；`local` 则始终使用本地文件。

CloudBase 本地配置示例：

```env
DATA_STORE=cloudbase
UPLOAD_STORAGE=auto
CLOUDBASE_ENV_ID=your-cloudbase-env-id
CLOUDBASE_SECRET_ID=
CLOUDBASE_SECRET_KEY=
```

凭证通过实际部署环境配置；代码也兼容 `CLOUDBASE_SECRETID`、`CLOUDBASE_SECRETKEY` 等旧变量名。数据库保存文件引用与元数据，图片本体保存在文件存储。临时图片 URL 会过期，不能当作永久存储地址。

### 真实模型

将 `AI_PROVIDER` 改为 `ark`，再填写密钥与所需模型配置。默认 Ark 地址为 `https://ark.cn-beijing.volces.com/api/v3`。真实参考图生成需模型可访问的图片来源；本地 `uploads/` 地址主要用于 mock 和本地分析联调。

## 接口入口

- 健康检查：`GET /health`
- 文本聊天：`POST /chat`
- 用户：`POST /v1/users/upsert`、`GET /v1/users/:userId/profile`
- 作品：`GET /v1/users/:userId/artworks`、`POST /v1/artworks/analyze`
- 图片上传：`POST /v1/uploads/image`
- 会员：`GET /v1/membership/plans`、`POST /v1/users/:userId/membership`
- 参考方向与生成：`POST /v1/artworks/:artworkId/reference-direction`、`POST /v1/artworks/:artworkId/generate-reference`

请求、响应及错误字段见 [API_CONTRACT.md](API_CONTRACT.md)，以 [src/server.js](src/server.js) 的实际路由为准。会员切换目前用于开发，正式上线前需要认证、资源访问控制和支付校验。

## 代码与后续工作

`src/server.js` 负责路由，`services/` 编排业务，`providers/` 对接模型，`repositories/` 隔离数据与文件存储。测试位于 `test/`。

当前待办见[项目状态](../docs/PROJECT_STATUS.md)，部署见 [DEPLOYMENT.md](DEPLOYMENT.md) 与 [CloudBase 运维说明](../docs/CLOUDBASE_RUNBOOK.md)。[BLUEPRINT.md](BLUEPRINT.md) 保留设计背景，历史交接位于 `../docs/handoff/`。
