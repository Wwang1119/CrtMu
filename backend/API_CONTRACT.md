# CrtMu 后端接口契约

这份文档是 Flutter 客户端和 Node.js 后端之间的约定。后续开发时，尽量保持这些接口路径和核心字段兼容；如果必须破坏兼容性，应该新开版本接口，而不是直接改旧接口。

## 通用响应格式

成功响应通常包含：

```json
{
  "ok": true
}
```

失败响应通常包含：

```json
{
  "ok": false,
  "error": "错误说明",
  "details": {}
}
```

说明：

- `ok`：是否成功
- `error`：给开发者或前端展示的错误信息
- `details`：可选字段，用来放更详细的错误信息

## `GET /health`

用途：检查后端是否启动成功，以及当前 provider 配置状态。

响应示例：

```json
{
  "ok": true,
  "service": "crtmu-backend",
  "provider": "mock",
  "modelReady": false,
  "visionReady": false,
  "imageReady": false,
  "time": "2026-05-21T00:00:00.000Z"
}
```

Flutter 当前不依赖这个接口做业务，只用于调试和部署检查。

## `POST /chat`

用途：发送一段文字给后端，由后端转发给 AI provider 或 mock provider。

请求：

```json
{
  "message": "请点评这幅画的构图"
}
```

字段说明：

- `message`：必填，用户输入的文本

成功响应：

```json
{
  "ok": true,
  "provider": "mock",
  "reply": "这里是后端返回的回复"
}
```

Flutter 当前依赖字段：

- `reply`

常见失败：

```json
{
  "ok": false,
  "error": "message is required"
}
```

## `POST /v1/uploads/image`

用途：上传作品图片，后端保存图片并返回 `uploadId`。

请求格式：`multipart/form-data`

字段说明：

- `file`：必填，图片文件
- `userId`：可选，上传者 ID

成功响应：

```json
{
  "ok": true,
  "upload": {
    "id": "upload-id",
    "userId": "user_me",
    "filename": "generated-file-name.jpg",
    "originalName": "artwork.jpg",
    "mimeType": "image/jpeg",
    "size": 123456,
    "path": "uploads/generated-file-name.jpg",
    "localUrl": "http://127.0.0.1:3000/uploads/generated-file-name.jpg",
    "createdAt": "2026-05-21T00:00:00.000Z"
  }
}
```

Flutter 当前依赖字段：

- `upload.id`
- `upload.localUrl`

注意：真实模型生成或图片编辑通常需要公网可访问图片 URL。本地开发时，mock 模式可以直接使用本地上传地址。

## `POST /v1/artworks/analyze`

用途：让后端分析一张作品，并把分析结果保存进作品档案。

请求：

```json
{
  "userId": "user_me",
  "studentName": "我",
  "title": "artwork.jpg",
  "uploadId": "upload-id",
  "imageUrl": "",
  "studentNote": ""
}
```

字段说明：

- `userId`：必填，用户 ID
- `uploadId`：可选，上传接口返回的图片 ID
- `imageUrl`：可选，外部图片 URL
- `studentName`：可选，学生姓名
- `title`：可选，作品标题
- `studentNote`：可选，学生补充说明

规则：

- `userId` 必须存在
- `uploadId` 和 `imageUrl` 至少要有一个
- 如果同时传 `uploadId` 和 `imageUrl`，当前后端优先使用 `imageUrl`

成功响应：

```json
{
  "ok": true,
  "provider": "mock",
  "artwork": {
    "id": "artwork-id",
    "userId": "user_me",
    "uploadId": "upload-id",
    "title": "artwork.jpg",
    "imageUrl": "http://127.0.0.1:3000/uploads/file.jpg",
    "studentNote": "",
    "createdAt": "2026-05-21T00:00:00.000Z",
    "critique": {
      "summary": "整体点评",
      "scores": {
        "composition": 80,
        "shape": 70,
        "color": 66,
        "light": 60
      },
      "strengths": ["主体明确"],
      "weaknesses": ["明暗还可加强"],
      "revisionSuggestions": ["先做黑白灰练习"],
      "nextExercise": "15 分钟重画练习",
      "tags": ["色彩练习"],
      "referencePrompt": "用于生成参考图的提示词"
    },
    "generation": {
      "status": "locked",
      "requiredTier": "pro",
      "prompt": "用于生成参考图的提示词"
    }
  },
  "profile": {
    "user": {},
    "stats": {},
    "recurringStrengths": [],
    "recurringWeaknesses": [],
    "recentArtworks": []
  }
}
```

Flutter 当前依赖字段：

- `artwork.id`
- `artwork.generation.status`
- `artwork.critique.summary`
- `artwork.critique.scores.composition`
- `artwork.critique.scores.shape`
- `artwork.critique.scores.color`
- `artwork.critique.scores.light`
- `artwork.critique.strengths`
- `artwork.critique.weaknesses`
- `artwork.critique.revisionSuggestions`
- `artwork.critique.nextExercise`

`generation.status` 当前含义：

- `locked`：当前用户没有权限生成参考图
- `ready`：当前用户有权限，可以继续生成参考图
- `generating`：后端正在生成参考图
- `completed`：参考图已生成

## `POST /v1/artworks/:artworkId/generate-reference`

用途：为指定作品生成“优化方向参考图”。

路径参数：

- `artworkId`：作品 ID

成功响应：

```json
{
  "ok": true,
  "result": {
    "artworkId": "artwork-id",
    "status": "completed",
    "imageUrl": "https://example.com/reference.png",
    "note": "参考图已生成。",
    "prompt": "用于生成参考图的提示词"
  }
}
```

Flutter 当前依赖字段：

- `result.imageUrl`
- `result.note`

常见失败：

```json
{
  "ok": false,
  "error": "This feature requires Pro membership.",
  "details": {
    "requiredTier": "pro",
    "currentTier": "free"
  }
}
```

## `GET /v1/membership/plans`

用途：获取可用会员套餐。

成功响应：

```json
{
  "ok": true,
  "plans": [
    {
      "tier": "free",
      "title": "Free",
      "priceLabel": "免费",
      "features": ["作品基础点评"],
      "generationEnabled": false
    }
  ]
}
```

当前 Flutter 主聊天链路还没有使用这个接口，后续会员页面会用到。

## `POST /v1/users/upsert`

用途：创建或更新用户。

请求：

```json
{
  "userId": "user_me",
  "studentName": "我"
}
```

成功响应：

```json
{
  "ok": true,
  "user": {
    "id": "user_me",
    "studentName": "我",
    "membershipTier": "free",
    "createdAt": "2026-05-21T00:00:00.000Z",
    "updatedAt": "2026-05-21T00:00:00.000Z"
  }
}
```

后续做“用户身份”阶段时，这个接口会变得更重要。

## `POST /v1/users/:userId/membership`

用途：更新用户会员状态。当前更像开发调试接口，真实支付接入后应由支付回调或后端可信流程触发。

请求：

```json
{
  "membershipTier": "pro"
}
```

字段说明：

- `membershipTier`：只能是 `free` 或 `pro`

成功响应：

```json
{
  "ok": true,
  "user": {
    "id": "user_me",
    "membershipTier": "pro"
  }
}
```

## `GET /v1/users/:userId/profile`

用途：获取用户成长档案汇总。

成功响应：

```json
{
  "ok": true,
  "profile": {
    "user": {},
    "stats": {
      "artworkCount": 0,
      "averages": {
        "composition": null,
        "shape": null,
        "color": null,
        "light": null
      }
    },
    "recurringStrengths": [],
    "recurringWeaknesses": [],
    "recentArtworks": []
  }
}
```

后续做作品档案页时会用到。

## `GET /v1/users/:userId/artworks`

用途：获取某个用户的作品列表。

成功响应：

```json
{
  "ok": true,
  "artworks": []
}
```

后续做历史作品页时会用到。

## 后续维护原则

- Flutter 只依赖本文件明确写出的字段。
- 后端可以增加字段，但不要随意删除或改名已有字段。
- 如果接口必须破坏兼容性，优先新增 `/v2/...`，不要直接破坏旧客户端。
- 每次改接口，都要同步更新 Flutter model、测试和这份文档。
