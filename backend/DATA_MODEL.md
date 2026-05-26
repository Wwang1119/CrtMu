# CrtMu 后端数据模型说明

当前后端支持三种存储实现：默认 `DATA_STORE=json` 使用 `backend/data/app-db.json`，`DATA_STORE=cloudbase` 使用 CloudBase 文档型数据库，`DATA_STORE=mysql` 使用 CloudBase SQL / MySQL 8.0。
这一阶段的目标是保持 service 层只表达业务，repository 层负责数据读写，让 Flutter 不感知底层存储切换。

## JSON 存储结构

```json
{
  "version": 1,
  "users": [],
  "artworks": [],
  "uploads": []
}
```

## User

JSON 模式下，用户记录保存在 `users[]`；CloudBase 文档库模式下，对应 `users` 集合；MySQL 模式下，对应 `users` 表。

字段：

- `id`：用户 ID。当前由前端传入，后续用户身份阶段会改成稳定设备用户或登录用户。
- `studentName`：学生名称，用于作品点评上下文。
- `membershipTier`：会员等级。当前只有 `free` 和 `pro`。
- `createdAt`：创建时间，ISO 字符串。
- `updatedAt`：最后更新时间，ISO 字符串。

当前规则：

- 新用户默认 `membershipTier = "free"`。
- 如果用户再次 upsert 并传入新的 `studentName`，后端会更新名称。
- 会员状态现在仍在 user 记录里，后续如果会员逻辑复杂，可以拆成独立 membership/subscription 表。

## Upload

JSON 模式下，上传记录保存在 `uploads[]`；CloudBase 文档库模式下，对应 `uploads` 集合；MySQL 模式下，对应 `uploads` 表。

字段：

- `id`：上传记录 ID。
- `userId`：上传者 ID，可为空。
- `filename`：后端生成的文件名。
- `originalName`：用户上传时的原始文件名。
- `mimeType`：文件 MIME 类型。
- `size`：文件大小，单位 byte。
- `path`：服务器本地文件路径。
- `localUrl`：后端静态文件访问 URL。
- `createdAt`：上传时间，ISO 字符串。

当前规则：

- 只允许图片上传。
- 文件仍保存在本地 `uploads/` 目录。
- 后续正式部署时，可以把文件迁移到对象存储，但 service 层应继续通过 upload repository 查询上传记录。

## Artwork

JSON 模式下，作品记录保存在 `artworks[]`；CloudBase 文档库模式下，对应 `artworks` 集合；MySQL 模式下，对应 `artworks` 表。

字段：

- `id`：作品 ID。
- `userId`：作品所属用户 ID。
- `uploadId`：关联的上传记录 ID；如果作品来自外部 `imageUrl`，可以为空。
- `title`：作品标题。
- `imageUrl`：前端展示用图片 URL。
- `studentNote`：学生补充说明。
- `createdAt`：作品分析创建时间，ISO 字符串。
- `critique`：AI 作品点评结构。
- `generation`：参考图生成状态。

## Critique

`artwork.critique` 表示一次作品分析结果。

字段：

- `summary`：总体点评。
- `scores.composition`：构图分数。
- `scores.shape`：造型分数。
- `scores.color`：色彩分数。
- `scores.light`：光影分数。
- `strengths`：优点列表。
- `weaknesses`：待加强点列表。
- `revisionSuggestions`：修改建议列表。
- `nextExercise`：下一步练习。
- `tags`：标签列表。
- `referencePrompt`：生成参考图时使用的提示词。

## Generation

`artwork.generation` 表示参考图生成相关状态。

字段：

- `status`：生成状态。
- `requiredTier`：需要的会员等级，当前是 `pro`。
- `prompt`：生成参考图使用的提示词。
- `requestedAt`：用户请求生成方向的时间。
- `startedAt`：参考图生成开始时间。
- `completedAt`：参考图生成完成时间。
- `resultImageUrl`：生成出的参考图 URL。
- `note`：生成结果说明。

当前状态值：

- `locked`：当前用户没有权限生成参考图。
- `ready`：当前用户有权限生成参考图。
- `prompt_ready`：已经准备好生成方向提示词。
- `generating`：正在生成参考图；当前同步接口里主要作为过程状态，后续异步任务化时可以持久化。
- `completed`：参考图已生成。

## Repository 边界

当前后端有四层：

- `app-store.js`：最低层 JSON 文件适配器，只负责读写整个 JSON store。
- `json/*-json-repository.js`：JSON 文件存储实现，迁移期继续保留作为本地 fallback。
- `cloudbase/*-cloudbase-repository.js`：CloudBase 文档型数据库实现，用于低成本云端联调。
- `mysql/*-mysql-repository.js`：CloudBase MySQL 实现，先覆盖 `users`、`uploads`、`artworks`。
- `user-repository.js` / `upload-repository.js` / `artwork-repository.js`：公共 repository 入口，根据 `DATA_STORE` 选择具体实现。

service 层不应该直接访问 `store.users`、`store.artworks`、`store.uploads`。  
以后继续换 SQLite、PostgreSQL 或对象存储时，优先替换 repository 层，尽量不改 service 层业务逻辑。
