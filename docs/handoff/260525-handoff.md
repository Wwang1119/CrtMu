# CrtMu 第 6 步云端数据存储交接摘要

## 1. 当前任务目标

当前目标是完成 CrtMu 第 6 步“腾讯云 MySQL / 云端数据存储”验证，使后端不再依赖本地 `backend/data/app-db.json`，而是能在云端持久化 `users`、`uploads`、`artworks` 的当前读写能力。

预期产出：

- 后端 repository 层支持云端数据存储，service 层尽量不大改。
- Flutter 继续调用旧接口，不感知底层从 JSON 换成云端数据库。
- 本地开发仍保留 `DATA_STORE=json` fallback。
- 云端部署可通过 `/health` 确认当前数据源。
- 至少验证 `POST /v1/users/upsert` 能写入云端持久化数据库。

完成标准：

- `GET /health` 返回 `ok: true` 且 `dataStore` 为当前云端存储模式。
- `POST /v1/users/upsert` 返回 `ok: true`，并能在对应云端集合/表中看到 `verify_user_001`。
- 后续接口保持兼容：`POST /v1/uploads/image`、`POST /v1/artworks/analyze`、`GET /v1/users/:userId/profile`、`GET /v1/users/:userId/artworks`、`POST /v1/artworks/:artworkId/generate-reference`。
- 不提交任何真实数据库密码、API key、AI key。

## 2. 当前进展

已完成的代码改动：

- `backend/src/config.js`
  - 新增 `config.dataStore`，读取 `DATA_STORE`，默认 `json`。
  - 新增 MySQL `DB_*` 配置。
  - 新增 `cloudbaseEnvId`，读取 `CLOUDBASE_ENV_ID` 或 `TCB_ENV_ID`。

- `backend/src/server.js`
  - `/health` 增加返回 `dataStore: config.dataStore`。

- repository 切换层：
  - 新增 `backend/src/repositories/repository-selector.js`
  - 支持 `DATA_STORE=json`、`DATA_STORE=mysql`、`DATA_STORE=cloudbase`。

- JSON repository 保留并移动到：
  - `backend/src/repositories/json/user-json-repository.js`
  - `backend/src/repositories/json/upload-json-repository.js`
  - `backend/src/repositories/json/artwork-json-repository.js`

- MySQL repository 已实现但目前不适合体验版部署：
  - `backend/src/repositories/mysql/mysql-client.js`
  - `backend/src/repositories/mysql/mysql-utils.js`
  - `backend/src/repositories/mysql/user-mysql-repository.js`
  - `backend/src/repositories/mysql/upload-mysql-repository.js`
  - `backend/src/repositories/mysql/artwork-mysql-repository.js`

- CloudBase 文档型数据库 repository 已实现：
  - `backend/src/repositories/cloudbase/cloudbase-client.js`
  - `backend/src/repositories/cloudbase/cloudbase-utils.js`
  - `backend/src/repositories/cloudbase/user-cloudbase-repository.js`
  - `backend/src/repositories/cloudbase/upload-cloudbase-repository.js`
  - `backend/src/repositories/cloudbase/artwork-cloudbase-repository.js`

- public repository 入口已改为按 `DATA_STORE` 选择实现：
  - `backend/src/repositories/user-repository.js`
  - `backend/src/repositories/upload-repository.js`
  - `backend/src/repositories/artwork-repository.js`

- `backend/package.json`
  - 已添加 `mysql2`
  - 已添加 `@cloudbase/node-sdk`

- `backend/Dockerfile`
  - 已从 `RUN npm ci --omit=dev` 改为 `RUN npm install --omit=dev`
  - 原因：本地环境没有 `npm`，无法可靠刷新 `package-lock.json`；用 `npm install` 让云端构建根据 `package.json` 安装新增依赖。

- 文档更新：
  - `backend/.env.example`
  - `backend/README.md`
  - `backend/DATA_MODEL.md`
  - `backend/API_CONTRACT.md`
  - `docs/DATABASE_DESIGN.md`

已完成验证：

- 本地 JSON 模式测试通过：
  - 命令：`node --test`
  - 结果：4 个 Node test 全部通过。
- 本地 JS 语法检查通过：
  - 命令：`node --check` 遍历 `backend/src/**/*.js`
- 云托管 Docker 构建已经成功过：
  - 日志中出现 `npm ci --omit=dev added 91 packages` 是旧 MySQL 包版本。
  - 后来文档库版本改为 `npm install --omit=dev`。
- 云托管 `/health` 已经成功返回过：
  - MySQL 版本返回：
    ```json
    {"ok":true,"service":"crtmu-backend","provider":"mock","dataStore":"mysql",...}
    ```
  - 文档库版本应期望返回 `dataStore: "cloudbase"`，需接手者再确认当前线上版本。

已生成过的部署包：

- `dist/crtmu-backend-cloudbase-root.zip`：MySQL 版根目录 zip。
- `dist/crtmu-backend-cloudbase-docdb.zip`：初版 CloudBase 文档库 zip。
- `dist/crtmu-backend-cloudbase-docdb-v2.zip`：修复 `cloudbase.init is not a function` 后的 zip。
- `dist/crtmu-backend-cloudbase-docdb-v3.zip`：加 5 秒文档库调用超时后的 zip。

注意：最后一次打 `v3` 包的命令在上一轮被用户中断过，随后已重新执行并生成成功：

```text
D:\Projects\CrtMu\dist\crtmu-backend-cloudbase-docdb-v3.zip
```

## 3. 关键上下文

项目路径：

```text
D:\Projects\CrtMu
```

后端路径：

```text
D:\Projects\CrtMu\backend
```

CloudBase 环境：

```text
环境名：apps-prod
环境 ID：yudu-web-8g1ccrez1a12fa8d
```

原 MySQL 信息：

```text
内网地址：172.17.0.10:3306
数据库名：yudu-web-8g1ccrez1a12fa8d
数据库账号：crtmu_admin
外网地址：关闭，不建议打开
```

用户明确要求：

- 不要问用户数据库密码明文。
- 不要把数据库密码提交到 Git。
- 不要改动语渡相关独立云函数 `yudu-proxy`。
- service 层尽量不大改，优先替换 repository 层。
- 老接口继续能用，Flutter 不应该感知底层存储变化。
- 保留本地开发能力。

已做出的关键决定：

- MySQL repository 保留，但体验版 CloudBase 云托管无法开启私有网络/VPC，导致无法访问 MySQL 内网地址。
- 不建议打开 MySQL 公网地址绕过限制，风险过高。
- 临时转向更便宜的 CloudBase 文档型数据库，使用 `DATA_STORE=cloudbase`。
- 文档库集合名和当前 API 对象保持一致：
  - `users`
  - `uploads`
  - `artworks`
- 文档库权限建议全部设为 `ADMINONLY`，只允许后端服务访问，Flutter 不直连数据库。

当前云托管服务：

```text
服务名：crtmu-backend
域名示例：https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com
```

云托管部署配置应为：

```text
代码包类型：压缩包
目标目录：. 或留空
Dockerfile 文件：有
Dockerfile 名称：Dockerfile
访问端口：80
服务端口：3000
CMD：留空
ENTRYPOINT：留空
```

文档库方案环境变量应为：

```text
HOST=0.0.0.0
PORT=3000
DATA_STORE=cloudbase
CLOUDBASE_ENV_ID=yudu-web-8g1ccrez1a12fa8d
AI_PROVIDER=mock
```

云托管表单里 `API key 设置` 已被用户打开过，但当前是否真的注入有效 `CLOUDBASE_APIKEY` 未确认。用户截图中曾看到 `CLOUDBASE_APIKEY` 右侧 value 为空。

## 4. 关键发现

1. MySQL 卡住不是代码逻辑问题，而是 CloudBase 体验版能力限制。

MySQL 内网地址 `172.17.0.10:3306` 需要云托管开启私有网络/VPC 才能访问。用户截图显示“私有网络”开关带“标准版”标识，体验版不可用。`POST /v1/users/upsert` 曾返回：

```text
connect ETIMEDOUT
```

这符合后端无法访问 MySQL 内网地址的现象。

2. 不建议开 MySQL 外网地址。

理论上打开 MySQL 公网地址可以绕过 VPC 限制，但会暴露数据库端口到公网，存在扫描、暴力破解、凭证泄露后直接拖库、删库、刷连接数等风险。当前阶段不建议。

3. CloudBase 文档库方案目前卡在后端访问文档库超时。

用户执行：

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/upsert" -Method Post -ContentType "application/json" -Body '{"userId":"verify_user_001","studentName":"verify user"}'
```

当前返回过：

```json
{"ok":false,"error":"CloudBase document database timed out: users.findUserById"}
```

这说明：

- 公网请求能到达云托管后端。
- 后端进入了 `DATA_STORE=cloudbase` 路径。
- 卡在 `users.doc(userId).get()` 这一类 CloudBase 文档库 SDK 调用。

4. `cloudbase.init is not a function` 已修复。

曾经返回：

```text
cloudbase.init is not a function
```

已在 `backend/src/repositories/cloudbase/cloudbase-client.js` 修复为：

```js
const cloudbase = cloudbaseModule.default ?? cloudbaseModule;
```

5. 已加显式超时。

`backend/src/repositories/cloudbase/cloudbase-client.js` 中已新增 `withCloudbaseTimeout(operation, label)`，当前 5 秒超时，避免请求被网关拖成 504/503。

6. 503/504 不是用户电脑代理问题。

用户收到过：

```text
503 Service Temporarily Unavailable
nginx/1.17.8
```

以及 504。能收到 CloudBase nginx 响应说明请求已经到达腾讯云网关，不是本机全局代理没开导致。

7. 浏览器地址栏不能测试 POST。

用户曾在浏览器输入 `/v1/users/upsert` 或 `/POST%20/v1/users/upsert`，返回 `Cannot GET ...`。这只是因为地址栏发的是 GET。需要 PowerShell、Postman、Apifox 等发 POST。

## 5. 未完成事项

按优先级排序：

1. 查明 CloudBase 文档型数据库 SDK 超时根因。
   - 当前错误：`CloudBase document database timed out: users.findUserById`
   - 优先确认云托管服务是否真的注入有效 `CLOUDBASE_APIKEY`。
   - 优先查看云托管运行日志，确认环境变量、SDK 报错、网络访问细节。

2. 确认文档型数据库集合已创建且权限正确。
   - `users`
   - `uploads`
   - `artworks`
   - 权限应为 `ADMINONLY`。

3. 确认线上服务当前部署的是 `DATA_STORE=cloudbase` 新包。
   - 访问 `/health`，检查 `dataStore` 是否为 `cloudbase`。
   - 如果仍是 `mysql`，说明环境变量或部署版本没有切换成功。

4. 让 `POST /v1/users/upsert` 成功写入文档库。
   - 成功后到文档型数据库 `users` 集合里查 `verify_user_001`。

5. 成功写入后继续验证：
   - `GET /v1/users/verify_user_001/profile`
   - 后续可再验证上传和分析接口。

6. 最终清理/同步文档。
   - 如果文档库方案确定采用，需要把 `docs/DATABASE_DESIGN.md` 或新文档明确标为“当前低成本云端存储方案”。
   - MySQL 作为后续正式化方案保留即可。

## 6. 建议接手路径

优先查看文件：

```text
backend/src/config.js
backend/src/server.js
backend/src/repositories/repository-selector.js
backend/src/repositories/cloudbase/cloudbase-client.js
backend/src/repositories/cloudbase/user-cloudbase-repository.js
backend/src/repositories/cloudbase/upload-cloudbase-repository.js
backend/src/repositories/cloudbase/artwork-cloudbase-repository.js
backend/package.json
backend/Dockerfile
backend/.env.example
```

先本地确认：

```powershell
cd D:\Projects\CrtMu\backend
& 'C:\Users\wyxwy\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' --test
```

语法检查：

```powershell
Get-ChildItem -Recurse -Path D:\Projects\CrtMu\backend\src -Filter *.js |
  ForEach-Object {
    & 'C:\Users\wyxwy\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' --check $_.FullName
  }
```

如果需要重新打包，用当前已有模式：

```powershell
$source = Join-Path (Get-Location) 'backend'
$dist = Join-Path (Get-Location) 'dist'
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$zip = Join-Path $dist 'crtmu-backend-cloudbase-docdb-vNEXT.zip'
if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zip, [System.IO.Compression.ZipArchiveMode]::Create)
$paths = @('Dockerfile','package.json','package-lock.json','README.md','BLUEPRINT.md')
foreach ($relative in $paths) {
  $file = Join-Path $source $relative
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file, $relative.Replace('\','/')) | Out-Null
}
Get-ChildItem -Path (Join-Path $source 'src') -Recurse -File | ForEach-Object {
  $relative = $_.FullName.Substring($source.Length + 1).Replace('\','/')
  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $_.FullName, $relative) | Out-Null
}
$archive.Dispose()
Get-Item $zip
```

云端优先验证：

1. 访问：

```text
https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/health
```

确认返回：

```json
"dataStore": "cloudbase"
```

2. 发 POST：

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/upsert" -Method Post -ContentType "application/json" -Body '{"userId":"verify_user_001","studentName":"verify user"}'
```

3. 如果仍超时，下一步不要继续改业务代码，先查云托管日志和 CloudBase API Key 注入：

- 云托管 `crtmu-backend` 服务的“日志 / 版本日志 / 容器日志”
- 环境变量实际是否包含 `CLOUDBASE_APIKEY`
- CloudBase 控制台 `环境管理 -> API Key 配置` 是否创建了服务端 API Key
- 文档型数据库集合是否存在且权限为 `ADMINONLY`

推荐下一步动作：

- 在 `cloudbase-client.js` 临时增加安全的启动日志，只打印：
  - `DATA_STORE`
  - `CLOUDBASE_ENV_ID`
  - `Boolean(process.env.CLOUDBASE_APIKEY)`
  - 不打印 API key 具体值
- 增加一个临时 debug endpoint，例如 `GET /debug/env` 只在 `NODE_ENV !== 'production'` 或受控情况下使用，返回上述布尔状态。注意不要泄露 key。
- 或直接在云托管日志中查看环境变量注入是否成功。

## 7. 风险与注意事项

- 不要让用户发送或截图任何真实密码、API Key、数据库密码。
- 不要把 `DB_PASSWORD`、`CLOUDBASE_APIKEY`、AI key 写进代码或提交。
- 不要继续强推 MySQL 内网连接，体验版云托管不能开私有网络/VPC，除非用户愿意升级标准版。
- 不建议打开 MySQL 公网地址作为长期方案。公网数据库暴露风险高。
- 不要改动语渡相关独立云函数 `yudu-proxy`。
- 不要把 Flutter 改成直连数据库。安全路径必须保持 `Flutter -> backend API -> database`。
- 不要误判浏览器 `Cannot GET /v1/users/upsert` 为接口坏；该接口必须 POST。
- 不要把 CloudBase 文档库权限设为 `READONLY`、`PRIVATE` 等前端规则混用。当前设计是后端服务访问，集合建议 `ADMINONLY`。
- `package-lock.json` 目前可能未完全反映 `@cloudbase/node-sdk`，因为本机没有 `npm`。Dockerfile 已改为 `npm install --omit=dev`，云端构建应能安装依赖。若接手者本地有 npm，建议在 `backend/` 运行 `npm install` 正式刷新 lockfile。
- CloudBase SDK 超时可能不是集合不存在，而是鉴权/API Key/环境访问问题。优先查云托管日志和 API key 注入。

下一位 Agent 的第一步建议：

先不要改业务逻辑。第一步请访问线上 `/health` 确认 `dataStore=cloudbase`，然后查看云托管 `crtmu-backend` 的当前版本运行日志，重点确认 `CLOUDBASE_APIKEY` 是否实际注入。若日志不可见，先加一个只返回 `Boolean(process.env.CLOUDBASE_APIKEY)` 和 `config.cloudbaseEnvId` 的临时诊断输出，重新打包部署，再继续排查文档库 SDK 超时。
