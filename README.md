# CrtMu · AI 美术助教

CrtMu 是一个开发中的 AI 美术助教应用：通过聊天和上传画作，提供作品点评、学习建议与参考图。Flutter 客户端位于仓库根目录，Node.js 后端位于 `backend/`。

## 开发入口

| 要做的事 | 从这里开始 |
| --- | --- |
| 启动与联调 | 本页的「本地运行」 |
| 查看当前进度与待办 | [开发状态与待办](docs/PROJECT_STATUS.md) |
| 找代码、了解职责 | [工程结构](docs/ENGINEERING_STRUCTURE.md) |
| 修改接口或数据结构 | [接口契约](backend/API_CONTRACT.md)、[数据模型](backend/DATA_MODEL.md)、[数据库设计](docs/DATABASE_DESIGN.md) |
| 配置和部署后端 | [后端说明](backend/README.md)、[部署说明](backend/DEPLOYMENT.md)、[CloudBase 运维说明](docs/CLOUDBASE_RUNBOOK.md) |
| 准备 iOS 发布 | [App Store 检查清单](APPSTORE_CHECKLIST.md) |

## 当前能力与边界

代码已包含文本聊天、图片上传、结构化作品分析、参考图生成接口、作品档案、设备本地用户 ID，以及开发用 free / pro 会员状态。后端支持 mock 与 Ark / Doubao provider，业务记录可使用 JSON、CloudBase 文档数据库或 MySQL，图片可保存在本地或 CloudBase 云存储。

以上是仓库中的实现范围，不代表云端已部署或所有平台都已验证。设备用户 ID 还不是正式账号认证；会员切换接口用于开发，真实登录、支付与生产鉴权仍需完善。当前优先用 mock 在本地跑通完整流程。

```text
Flutter 客户端 → Node.js 后端 → AI provider
                         ├─ 业务数据：JSON / CloudBase / MySQL
                         └─ 图片：本地文件 / CloudBase 云存储
```

## 环境要求

- Flutter SDK：需包含 Dart 3.11.1 或更高的兼容 3.x 版本，见 [pubspec.yaml](pubspec.yaml)；未单独固定 Flutter 版本。
- Node.js 20+ 与 npm，后端依赖已提交锁文件。
- iOS/macOS 开发需要 macOS、Xcode 和 CocoaPods；Android 开发需要 Android SDK。

## 本地运行

### 1. 启动后端

```bash
git clone https://github.com/Wwang1119/CrtMu.git
cd CrtMu/backend
cp .env.example .env
npm ci
npm run dev
```

Windows 命令提示符中使用 `copy .env.example .env`。首次运行保持以下本地配置，无需模型或云服务凭证：

```env
DATA_STORE=json
UPLOAD_STORAGE=auto
AI_PROVIDER=mock
```

检查服务：

```bash
curl http://127.0.0.1:3000/health
```

预期响应含 `ok: true`、`provider: "mock"`、`dataStore: "json"`、`uploadStorage: "local"`。mock 返回示例内容，不调用真实模型。

### 2. 启动客户端

另开终端，在仓库根目录运行：

```bash
flutter doctor
flutter pub get
flutter devices
flutter run --dart-define=BACKEND_BASE_URL=http://127.0.0.1:3000
```

| 运行设备 | 后端地址 |
| --- | --- |
| iOS 模拟器 / macOS | `http://127.0.0.1:3000` |
| Android 模拟器 | `http://10.0.2.2:3000` |
| 同一 Wi-Fi 下的真机 | 电脑局域网 IP；后端需监听 `HOST=0.0.0.0`，并核对平台网络配置 |
| 正式移动端包 | 必须显式传入正式 HTTPS 后端地址 |

真机上的 `127.0.0.1` 指向手机自身。iOS/macOS 如遇原生依赖问题，在对应目录执行 `pod install` 后重试。

## 常用检查

在仓库根目录执行客户端检查：

```bash
flutter analyze
flutter test
```

在 `backend/` 执行后端检查：

```bash
npm ci
npm test
node --check src/server.js
```

Flutter 测试覆盖接口解析、聊天缓存、作品模型和本地身份等；后端测试包含会员限制、档案聚合和本地上传。云存储、真实模型及真机流程需另行联调，当前没有 GitHub Actions 自动检查。

## 主要目录

```text
lib/                  Flutter 应用、聊天、作品和用户功能
backend/src/          路由、业务服务、AI provider、存储适配
backend/test/         后端测试
test/                 Flutter 测试
docs/                 结构、数据库、运维和开发状态
docs/handoff/         按日期保留的历史交接记录
assets/               图片和图标
ios/、android/ 等     各平台工程
```

历史交接记录描述当时状态；当前能力以代码及[开发状态](docs/PROJECT_STATUS.md)为准。更改接口、配置或运行方式时，同步更新对应说明，提交信息写清本次解决的问题。

## 配置与资料

模型密钥只在后端配置。`.env`、上传图片、运行数据库及构建产物不应提交；从 [.env.example](backend/.env.example) 建立本地配置。云服务配置说明见[后端 README](backend/README.md)。

仓库尚未选择开源许可证；第三方代码、依赖和素材沿用各自许可。
