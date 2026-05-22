# CrtMu

CrtMu 是一个 AI 美术助教项目。当前版本的核心能力是：用户在 Flutter 客户端里聊天、上传作品图片，后端负责接收请求、保存上传文件，并通过 AI provider 返回文字点评、作品分析和参考图生成结果。

这个仓库目前由两部分组成：

- Flutter 客户端：项目根目录
- Node.js 后端：`backend/`

主链路是：

```text
Flutter 客户端 -> Node.js 后端 -> AI provider（mock / Ark / Doubao）
```

这样设计的原因是：模型密钥不能放在 App 客户端里，上传、超时、日志、会员权限和未来支付状态也应该统一放在后端处理。

## 当前状态

当前项目已经完成第一轮工程化整理：

- `lib/main.dart` 只保留启动入口
- `lib/app.dart` 负责 App 主题和首页挂载
- `lib/features/chat/` 负责聊天页面、聊天 UI、聊天缓存
- `lib/features/artwork/` 负责作品分析模型和点评文案格式化
- `lib/core/api/backend_api_client.dart` 负责 Flutter 访问后端
- `backend/src/` 保持 route / service / provider / repository 分层

更详细的结构说明见：

- `docs/ENGINEERING_STRUCTURE.md`
- `backend/DATA_MODEL.md`
- `backend/API_CONTRACT.md`

## 如何运行前端

先安装 Flutter 依赖：

```bash
flutter pub get
```

本机运行 Flutter：

```bash
flutter run
```

指定后端地址运行：

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:3000
```

Android 模拟器访问电脑本机后端时，要用：

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000
```

真机调试时，要把 `127.0.0.1` 换成电脑在同一 Wi-Fi 下的局域网 IP。

## 如何运行后端

进入后端目录：

```bash
cd backend
```

安装依赖：

```bash
npm install
```

复制环境变量示例：

```bash
copy .env.example .env
```

启动开发服务器：

```bash
npm run dev
```

后端默认地址：

```text
http://127.0.0.1:3000
```

检查后端是否启动成功：

```bash
curl http://127.0.0.1:3000/health
```

## 后端模式

当前后端支持两种 provider 模式：

- `AI_PROVIDER=mock`：本地假数据模式，不会请求真实模型，适合学习和联调
- `AI_PROVIDER=ark`：通过 Ark / Doubao 调用真实模型

刚开始开发时建议使用 `mock`，先把 Flutter 和后端链路跑通，再接真实模型。

## 常用接口

当前 Flutter 主要依赖这些接口：

- `GET /health`：健康检查
- `POST /chat`：文本聊天
- `POST /v1/uploads/image`：上传作品图片
- `POST /v1/artworks/analyze`：分析作品
- `POST /v1/artworks/:artworkId/generate-reference`：生成参考图

接口字段说明见 `backend/API_CONTRACT.md`。

## 测试

Flutter 测试：

```bash
flutter test
```

Flutter 静态检查：

```bash
flutter analyze
```

后端语法检查可以用：

```bash
node --check src/server.js
```

如果你在 Codex 环境里没有 `flutter` / `dart` 命令，需要回到本机 Flutter 环境里执行这些命令。

## 下一步开发顺序

建议按功能树一段一段做，不要一次性把所有东西都重构完。

### 0. 中文文档和学习路线

先保证 README、接口契约、工程结构说明都能读懂。

目标：知道项目是什么、怎么运行、当前结构是什么、下一步怎么做。

### 1. 数据边界

暂时不急着上 PostgreSQL。先整理后端 repository 层，让 `users`、`artworks`、`uploads`、`membership` 的读写边界更清楚。

目标：以后从 JSON 文件迁移到 SQLite / PostgreSQL 时，service 层不用大改。

### 2. 用户身份

不要继续永远写死 `user_me`。先做最小用户身份，让同一台设备重启后仍然能识别同一个用户。

目标：后续作品档案、会员状态、支付结果都有稳定归属。

### 3. 会员状态

先做开发版 free / pro 状态，不急着接真实支付。

目标：后端负责判断权限，前端只展示会员状态和入口。

### 4. 支付

等用户身份和会员状态稳定后，再接支付。

目标：支付成功后可靠地更新用户会员状态。

### 5. 完整前端展示

最后再完善个人页、作品档案页、会员页、支付页和历史作品页。

注意：前端不是完全放到最后。每个阶段都应该做一个最小 UI 入口，用来验证这条链路真的跑通。

## 学习重点

这个项目适合用来练习真正的软件工程能力：

- 职责分离
- 前后端接口契约
- 数据模型设计
- 本地缓存
- 后端分层
- AI provider 抽象
- 测试保护
- 从 demo 逐步演进成长期维护项目

每做完一个功能分支，建议回来检查一次：代码边界是否清楚、接口是否稳定、测试是否覆盖、有没有引入新的技术债。
