# CrtMu 工程化结构说明

这份文档记录当前代码的主要边界。开发进度与后续任务见 [PROJECT_STATUS.md](PROJECT_STATUS.md)。

## Flutter client

### App 层

- `lib/main.dart`：只负责 Flutter 启动和系统 UI 设置。
- `lib/app.dart`：只负责 `MaterialApp`、主题和首页挂载。

学习点：入口越薄，后续换首页、加路由、调主题时越不容易牵连业务代码。

### Chat feature

- `lib/features/chat/chat_page.dart`：聊天页，负责把用户动作转成业务调用，并把结果插回消息流。
- `lib/features/chat/widgets/`：聊天 UI 组件和 builder。
- `lib/features/chat/services/chat_cache_service.dart`：聊天记录本地缓存。
- `lib/features/chat/utils/chat_text_utils.dart`：聊天相关的小工具函数。

学习点：页面可以编排流程，但不应该直接拼接口、解析复杂 JSON、读写缓存文件。

### Artwork feature

- `lib/features/artwork/models/artwork_models.dart`：后端作品分析响应的 Dart 模型。
- `lib/features/artwork/services/artwork_critique_formatter.dart`：把结构化点评转换成聊天文案。

学习点：模型解析集中后，后端字段变化时不用满项目找 `json['xxx']`。

### Core layer

- `lib/core/api/backend_api_client.dart`：Flutter 访问后端的唯一入口。
- `lib/core/network/backend_config.dart`：后端地址解析。

学习点：UI 层只知道“我要发送文本/上传图片”，不关心 HTTP header、URL、超时和错误细节。

### User feature

- `lib/features/user/services/local_user_identity_service.dart`：生成并持久化设备本地用户 ID。
- `lib/features/user/models/user_profile_models.dart`：用户与档案响应模型。
- 聊天页提供基础用户状态入口；设备 ID 不等同于正式登录认证。

## Backend

后端继续保持当前分层：

- `backend/src/server.js`：路由入口和请求字段规范化。
- `backend/src/services/`：业务逻辑。
- `backend/src/providers/`：AI provider 适配。
- `backend/src/repositories/`：数据和文件存储边界。业务记录可以走 JSON、CloudBase 文档型数据库或 MySQL；上传图片本体可以走本地 `uploads/` 或 CloudBase 云存储。
- `backend/API_CONTRACT.md`：Flutter 和后端之间的接口契约。

## 当前刻意不做的事

- 暂不引入 Riverpod/Bloc，避免第一轮重构同时改变状态管理方式。
- 暂不做手机号 / 微信登录和真实支付。
- 暂不做完整 UI，先保证每条后端链路能被当前聊天界面验证。
- MySQL 适配代码已经存在；当前云端开发路径以 CloudBase 文档型数据库为主，切换存储前需单独验证。
- 暂不把 CloudBase 云存储细节散落到业务服务里，继续通过 repository / service 边界封装。
