# CrtMu CloudBase 云存储接入交接

时间：2026-06-16  
当前分支：`main`  
关键提交：`9051a66 Add CloudBase upload storage`

## 当前结论

CloudBase 文档数据库已经接上了。

云端接口验证结果：

- `GET /health` 返回 `dataStore: "cloudbase"`
- `POST /v1/users/upsert` 成功写入测试用户 `verify_user_codex_20260616`
- 可以去 CloudBase 文档型数据库 `users` 集合里确认这条记录

CloudBase 云存储还没有真正跑起来。

原因不是环境变量，而是云托管当前运行的仍然是旧后端代码。旧代码的上传接口返回：

```json
{
  "path": "/app/uploads/xxx.png",
  "localUrl": "https://.../uploads/xxx.png"
}
```

新代码部署成功后，`POST /v1/uploads/image` 应该返回：

```json
{
  "storage": "cloudbase",
  "fileId": "cloud://...",
  "cloudPath": "uploads/...",
  "localUrl": "https://..."
}
```

并且 `GET /health` 应该多出：

```json
{
  "uploadStorage": "cloudbase"
}
```

## 已完成代码改动

已把图片上传从本地目录抽象成文件存储 repository：

- `backend/src/repositories/upload-file-repository.js`
- `backend/src/repositories/local/upload-file-local-repository.js`
- `backend/src/repositories/cloudbase/upload-file-cloudbase-repository.js`

核心行为：

- `DATA_STORE=cloudbase` 且 `UPLOAD_STORAGE=auto` 时，图片上传到 CloudBase 云存储 / COS
- 本地开发或 `UPLOAD_STORAGE=local` 时，继续写 `backend/uploads/`
- 数据库 `uploads` 集合只保存文件引用和元数据，不保存图片二进制
- Flutter 接口保持兼容，仍然返回 `upload.id` 和 `upload.localUrl`

已更新：

- `backend/src/services/upload-service.js`
- `backend/src/services/artwork-service.js`
- `backend/src/services/critique-service.js`
- `backend/src/config.js`
- `backend/src/server.js`
- `backend/.env.example`
- `backend/API_CONTRACT.md`
- `README.md`
- `docs/CLOUDBASE_RUNBOOK.md`

已提交并推送：

```text
9051a66 Add CloudBase upload storage
```

已推到：

- `origin/main`
- `origin/codex/云存储`

## 当前云托管环境变量

用户已经在云托管里配置过：

```env
HOST=0.0.0.0
PORT=3000
DATA_STORE=cloudbase
CLOUDBASE_ENV_ID=yudu-web-8g1ccrez1a12fa8d
AI_PROVIDER=mock
CLOUDBASE_TIMEOUT_MS=15000
CLOUDBASE_SECRETID=...
CLOUDBASE_SECRETKEY=...
CLOUDBASE_APIKEY=...
```

后续还应该确认存在：

```env
UPLOAD_STORAGE=auto
CLOUDBASE_STORAGE_PREFIX=uploads
CLOUDBASE_TEMP_URL_MAX_AGE_SECONDS=86400
```

代码兼容两套密钥命名：

```env
CLOUDBASE_SECRET_ID
CLOUDBASE_SECRET_KEY
```

以及旧命名：

```env
CLOUDBASE_SECRETID
CLOUDBASE_SECRETKEY
```

注意：用户曾把真实密钥贴到聊天里，建议轮换 CloudBase API key 和 CAM Secret。

## 已验证命令

云端健康检查：

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/health" -Method Get
```

当前返回旧代码形态，没有 `uploadStorage` 字段。

数据库写入验证：

```powershell
Invoke-RestMethod `
  -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/upsert" `
  -Method Post `
  -ContentType "application/json" `
  -Body '{"userId":"verify_user_codex_20260616","studentName":"Codex 验证用户"}'
```

返回成功，说明文档数据库接通。

图片上传验证：

```powershell
curl.exe -sS -X POST `
  "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/uploads/image" `
  -F "userId=verify_user_codex_20260616" `
  -F "file=@assets/images/icon.png;type=image/png"
```

返回仍是旧本地上传字段，说明云存储新版代码未部署生效。

## 部署包情况

错误包：

```text
crtmu-backend-cloudbase-9051a66.zip
```

这个包已经删除。它的问题是把整个 `backend/` 都压进去了，包括：

- `test/`
- `data/`
- `db/`
- `uploads/`
- `.env.example`
- 其他非部署文件

后来重新按 v6 结构做了：

```text
D:\Projects\CrtMu\crtmu-backend-cloudbase-v7.zip
```

v7 包结构如下：

```text
Dockerfile
package.json
package-lock.json
README.md
BLUEPRINT.md
src/
```

但用户反馈 v7 仍然部署失败。还没有拿到 CloudBase 云托管的失败日志。

## 下一窗口优先排查

第一步：一定要先看 CloudBase 云托管构建失败日志。

路径大致是：

```text
CloudBase 控制台 -> 云托管 -> crtmu-backend -> 部署记录 / 构建日志
```

需要复制失败日志里的关键几行，尤其是：

- `npm install` 是否失败
- 是否找不到 `@cloudbase/node-sdk`
- 是否 Dockerfile 路径不对
- 是否压缩包根目录不对
- 是否 Node 版本不对
- 是否因为 `package-lock.json` 和 `package.json` 不一致失败

第二步：如果日志显示依赖安装问题，优先处理 `package-lock.json`。

当前 `backend/package.json` 有：

```json
"@cloudbase/node-sdk": "^2.11.0"
```

但 `backend/package-lock.json` 顶层依赖里没有 `@cloudbase/node-sdk`。本机没有可用 `npm`，所以之前没法正规刷新 lock。

解决方式之一：

```bash
cd backend
npm install
```

然后重新打包部署。

第三步：如果日志显示压缩包目录问题，可以直接用 GitHub 部署，不要上传 zip。

GitHub 已经推送：

```text
repo: Wwang1119/CrtMu
branch: main
commit: 9051a66
```

云托管选择 GitHub 部署时，注意构建目录应该是：

```text
backend
```

因为 `Dockerfile` 在 `backend/Dockerfile`，不是仓库根目录。

如果云托管只支持上传代码包，则压缩包根目录必须直接包含：

```text
Dockerfile
package.json
package-lock.json
src/
```

不能是：

```text
backend/Dockerfile
backend/package.json
backend/src/
```

第四步：部署成功后验证。

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/health" -Method Get
```

必须看到：

```json
{
  "dataStore": "cloudbase",
  "uploadStorage": "cloudbase"
}
```

再上传图片，必须看到：

```json
{
  "storage": "cloudbase",
  "fileId": "...",
  "cloudPath": "uploads/..."
}
```

## 重要提醒

用户贴的 CloudBase 指引是 CommonJS 写法：

```js
const cloudbaseSDK = require("@cloudbase/node-sdk");
```

本项目是 ESM：

```json
{
  "type": "module"
}
```

所以不要直接照抄 `require` 示例。当前代码已经用动态 import 接入：

```js
cloudbaseModule = await import('@cloudbase/node-sdk');
```

对应文件：

```text
backend/src/repositories/cloudbase/cloudbase-client.js
```

## 当前工作区状态

`main` 已经包含云存储提交并推送到 GitHub。

仍有一个未跟踪文件：

```text
260525-handoff.md
```

这个文件不是本任务产生的，之前没有动它。
