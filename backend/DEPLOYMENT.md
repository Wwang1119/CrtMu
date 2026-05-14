# CrtMu 后端部署说明

这份说明面向“先上线、后迭代”的第一版。

## 推荐路线

第一版最稳的方式：

- Flutter 客户端继续保留现在的聊天 UI
- 后端继续使用当前 `Node + Express`
- 先部署到一台小型 Linux 云服务器
- 用 HTTPS 域名给 iPhone 正式包调用

这样做的好处是：

- 结构清晰，后面继续加会员、作品档案、支付更顺
- 图片上传和静态文件服务比云函数更直观
- 成本通常就是“小服务器 + 对象存储 + 模型调用”

## 为什么不是直接用电脑

你的电脑上的后端只适合开发测试。

上架 App Store 后，用户手机不能依赖你的电脑一直开着，所以要换成公网可访问的正式后端。

## Docker 部署

后端已经带上了 `Dockerfile`，可以直接部署。

### 1. 准备服务器

推荐最低起步：

- 2 核 CPU
- 2 GB 内存
- 40 GB 磁盘
- Ubuntu 22.04 LTS

### 2. 上传项目

把 `backend/` 整个目录传到服务器，比如：

`/opt/crtmu/backend`

### 3. 准备环境变量

在服务器上的 `backend/` 目录里创建 `.env`，至少填这些：

```env
PORT=3000
HOST=0.0.0.0
PUBLIC_BASE_URL=https://api.你的域名.com
AI_PROVIDER=mock
ARK_BASE_URL=https://ark.cn-beijing.volces.com/api/v3
ARK_API_KEY=
ARK_TEXT_MODEL=
ARK_VISION_MODEL=
ARK_IMAGE_MODEL=
ARK_TIMEOUT_MS=60000
```

说明：

- `PUBLIC_BASE_URL` 很重要，上传图片后返回给 App 的图片链接会用它
- 正式上线时建议把 `AI_PROVIDER` 切成 `ark`
- 没有真实模型前，先用 `mock` 把整条链路跑通

### 4. 构建镜像

```bash
cd /opt/crtmu/backend
docker build -t crtmu-backend .
```

### 5. 启动容器

```bash
docker run -d \
  --name crtmu-backend \
  --restart unless-stopped \
  --env-file .env \
  -p 3000:3000 \
  -v /opt/crtmu/data:/app/data \
  -v /opt/crtmu/uploads:/app/uploads \
  crtmu-backend
```

这里两个挂载目录的作用：

- `/opt/crtmu/data`：保存当前 JSON 数据库
- `/opt/crtmu/uploads`：保存用户上传图片

如果不挂载，容器重建后这些文件会丢失。

### 6. 验证接口

```bash
curl https://api.你的域名.com/health
```

期待看到类似：

```json
{
  "ok": true,
  "service": "crtmu-backend"
}
```

## HTTPS

iPhone 正式版强烈建议只连 HTTPS 接口。

最常见做法：

- Nginx 反向代理到 `127.0.0.1:3000`
- 用 Let’s Encrypt 申请证书

这样 App 里只需要配置：

`https://api.你的域名.com`

## Flutter 正式包

正式打包时不要再连 `localhost`。

请用：

```bash
flutter build ipa \
  --release \
  --dart-define=BACKEND_BASE_URL=https://api.你的域名.com
```

如果你忘了传 `BACKEND_BASE_URL`，现在 App 在正式版里会直接报清晰错误，避免把错误包提到 App Store。

## 当前存储方式

第一版为了尽快上线，后端仍然使用：

- `data/app-db.json`
- `uploads/`

这适合早期测试和小规模首发。

后面用户多了，再升级成：

- `SQLite` 作为第一步数据库升级
- `PostgreSQL` 作为正式云数据库
- `COS / TOS` 作为正式图片存储

## 上架前最少检查项

1. 后端公网域名可访问
2. 后端为 HTTPS
3. `GET /health` 正常
4. App 用正式域名打包
5. iOS 已配置相册权限说明
6. App 图标、名称、版本号已确认

## 建议的上线节奏

最稳的顺序是：

1. 先把后端部署到公网
2. 先用 `mock` 跑通真机完整链路
3. 再切真实豆包/方舟密钥
4. 再打 TestFlight
5. 最后再提交 App Store 审核
