# CrtMu 云端数据库设计

这份文档是第 5 步“云端数据表设计”的草稿。它先把业务关系讲清楚，下一步再根据这里的设计编写 CloudBase MySQL 初始化 SQL 或迁移脚本。

当前本地后端仍然使用 `backend/data/app-db.json`。迁移到云端数据库时，目标是优先替换 repository 层，尽量不大改 service 层和 Flutter 接口。

## 设计原则

- 用户是根数据。作品、上传文件、会员订单、支付记录和 AI 任务都必须能追溯到 `user_id`。
- 图片不直接存进数据库。图片本体放 CloudBase 云存储或 COS，数据库只保存 `object_key`、URL 和元数据。
- 会员权限由后端判断。前端只展示会员状态，不决定用户能不能生成参考图。
- 支付必须先创建订单，再记录支付流水，最后更新会员状态。
- 长任务要有状态记录。AI 分析、参考图生成、失败重试等流程后续可以通过 `ai_jobs` 跟踪。
- 数据库字段使用 `snake_case`，接口返回给 Flutter 时可以继续使用当前的 `camelCase`。

## 表关系概览

```text
users
  ├── artworks
  │     ├── uploads
  │     └── ai_jobs
  ├── uploads
  └── membership_orders
          └── payments
```

## 1. `users` 用户表

用途：保存匿名用户、登录用户、会员状态和基础档案。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 用户主 ID，后端生成，建议使用 UUID |
| `anonymous_id` | `varchar(64)` | 否 | 本地匿名用户 ID，用于登录前识别同一台设备 |
| `student_name` | `varchar(100)` | 否 | 学生名称或昵称 |
| `phone` | `varchar(32)` | 否 | 手机号，后续接手机号登录时使用 |
| `wechat_openid` | `varchar(128)` | 否 | 微信 openid，后续接微信登录时使用 |
| `apple_user_id` | `varchar(128)` | 否 | Apple 登录用户 ID，iOS 登录时使用 |
| `membership_tier` | `varchar(20)` | 是 | 会员等级：`free` / `pro` |
| `membership_expire_at` | `datetime` | 否 | 会员到期时间，免费用户可为空 |
| `created_at` | `datetime` | 是 | 创建时间 |
| `updated_at` | `datetime` | 是 | 更新时间 |
| `last_login_at` | `datetime` | 否 | 最近登录或最近打开 App 时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按用户 ID 查询 |
| `UNIQUE (anonymous_id)` | 唯一索引 | 防止同一个匿名身份重复建用户 |
| `UNIQUE (phone)` | 唯一索引 | 后续手机号登录用，允许空值 |
| `UNIQUE (wechat_openid)` | 唯一索引 | 后续微信登录用，允许空值 |
| `UNIQUE (apple_user_id)` | 唯一索引 | 后续 Apple 登录用，允许空值 |

当前本地 JSON 对应关系：

```text
users[].id                -> users.id
users[].studentName       -> users.student_name
users[].membershipTier    -> users.membership_tier
users[].createdAt         -> users.created_at
users[].updatedAt         -> users.updated_at
```

## 2. `artworks` 作品表

用途：保存作品档案、AI 点评结果和参考图生成状态。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 作品 ID |
| `user_id` | `varchar(36)` | 是 | 所属用户，对应 `users.id` |
| `title` | `varchar(100)` | 否 | 作品标题 |
| `description` | `text` | 否 | 用户备注或学生补充说明 |
| `status` | `varchar(20)` | 是 | 作品状态：`draft` / `uploaded` / `analyzing` / `done` / `failed` |
| `cover_upload_id` | `varchar(36)` | 否 | 作品主图，对应 `uploads.id` |
| `image_url` | `text` | 否 | 前端展示图 URL，迁移期兼容当前接口 |
| `critique_json` | `json` 或 `text` | 否 | AI 点评结构，保存 summary、scores、strengths 等完整结果 |
| `generation_json` | `json` 或 `text` | 否 | 参考图生成状态，兼容当前 `generation` 结构 |
| `analysis_summary` | `text` | 否 | AI 分析摘要，便于列表页快速展示 |
| `created_at` | `datetime` | 是 | 创建时间 |
| `updated_at` | `datetime` | 是 | 更新时间 |
| `deleted_at` | `datetime` | 否 | 软删除时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按作品 ID 查询 |
| `INDEX (user_id)` | 普通索引 | 查询某个用户的作品 |
| `INDEX (user_id, created_at)` | 组合索引 | 查询用户作品列表并按时间排序 |
| `INDEX (status)` | 普通索引 | 查询分析中或失败的作品 |

当前本地 JSON 对应关系：

```text
artworks[].id             -> artworks.id
artworks[].userId         -> artworks.user_id
artworks[].uploadId       -> artworks.cover_upload_id
artworks[].title          -> artworks.title
artworks[].studentNote    -> artworks.description
artworks[].imageUrl       -> artworks.image_url
artworks[].critique       -> artworks.critique_json
artworks[].generation     -> artworks.generation_json
artworks[].createdAt      -> artworks.created_at
```

## 3. `uploads` 上传文件表

用途：保存用户上传图片、生成参考图、头像等文件的元数据。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 上传记录 ID |
| `user_id` | `varchar(36)` | 否 | 上传者，对应 `users.id` |
| `artwork_id` | `varchar(36)` | 否 | 所属作品，对应 `artworks.id` |
| `kind` | `varchar(30)` | 是 | 文件用途：`original` / `reference` / `generated` / `avatar` |
| `object_key` | `varchar(255)` | 是 | 云存储路径，例如 `users/{userId}/artworks/{artworkId}/original.png` |
| `url` | `text` | 否 | 前端可访问 URL，可能是临时 URL |
| `original_name` | `varchar(255)` | 否 | 用户上传时的原始文件名 |
| `mime_type` | `varchar(50)` | 是 | 文件 MIME 类型，例如 `image/png` |
| `size_bytes` | `int` | 是 | 文件大小，单位 byte |
| `width` | `int` | 否 | 图片宽度 |
| `height` | `int` | 否 | 图片高度 |
| `created_at` | `datetime` | 是 | 上传时间 |
| `deleted_at` | `datetime` | 否 | 删除时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按上传 ID 查询 |
| `INDEX (user_id)` | 普通索引 | 查询用户上传记录 |
| `INDEX (artwork_id)` | 普通索引 | 查询某个作品的文件 |
| `UNIQUE (object_key)` | 唯一索引 | 防止同一个云存储对象重复入库 |
| `INDEX (kind)` | 普通索引 | 按文件用途筛选 |

当前本地 JSON 对应关系：

```text
uploads[].id              -> uploads.id
uploads[].userId          -> uploads.user_id
uploads[].filename        -> uploads.object_key 或迁移期文件名
uploads[].originalName    -> uploads.original_name
uploads[].mimeType        -> uploads.mime_type
uploads[].size            -> uploads.size_bytes
uploads[].localUrl        -> uploads.url
uploads[].createdAt       -> uploads.created_at
```

迁移到云存储后，`path` 不再保存本地文件路径，只保留云端 `object_key`。

## 4. `membership_orders` 会员订单表

用途：保存用户购买会员的订单。用户点击开通会员时，先创建这里的一条记录。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 订单 ID |
| `order_no` | `varchar(64)` | 是 | 对外订单号，传给支付平台，必须唯一 |
| `user_id` | `varchar(36)` | 是 | 下单用户，对应 `users.id` |
| `plan` | `varchar(30)` | 是 | 套餐：`pro_monthly` / `pro_yearly` |
| `amount_cents` | `int` | 是 | 金额，单位分 |
| `currency` | `varchar(10)` | 是 | 币种，例如 `CNY` |
| `status` | `varchar(20)` | 是 | 订单状态：`pending` / `paid` / `cancelled` / `refunded` / `expired` |
| `membership_days` | `int` | 是 | 这笔订单增加的会员天数 |
| `membership_start_at` | `datetime` | 否 | 本次会员开始时间 |
| `membership_expire_at` | `datetime` | 否 | 本次会员到期时间 |
| `paid_at` | `datetime` | 否 | 支付成功时间 |
| `created_at` | `datetime` | 是 | 创建时间 |
| `updated_at` | `datetime` | 是 | 更新时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按订单 ID 查询 |
| `UNIQUE (order_no)` | 唯一索引 | 支付回调通过订单号定位订单 |
| `INDEX (user_id, created_at)` | 组合索引 | 查询用户订单历史 |
| `INDEX (status)` | 普通索引 | 查询待支付、已支付或过期订单 |

订单状态流转：

```text
pending -> paid
pending -> cancelled
pending -> expired
paid    -> refunded
```

## 5. `payments` 支付流水表

用途：保存支付平台回调记录。即使同一个订单被重复回调，也要能识别并避免重复开通会员。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 支付记录 ID |
| `order_id` | `varchar(36)` | 是 | 对应 `membership_orders.id` |
| `order_no` | `varchar(64)` | 是 | 对应 `membership_orders.order_no` |
| `provider` | `varchar(30)` | 是 | 支付渠道：`wechat` / `apple_iap` / `manual` |
| `provider_trade_no` | `varchar(128)` | 否 | 支付平台流水号 |
| `amount_cents` | `int` | 是 | 实付金额，单位分 |
| `currency` | `varchar(10)` | 是 | 币种，例如 `CNY` |
| `status` | `varchar(20)` | 是 | 支付状态：`success` / `failed` / `refunded` |
| `raw_payload` | `json` 或 `text` | 否 | 支付平台原始回调内容 |
| `created_at` | `datetime` | 是 | 创建时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按支付记录 ID 查询 |
| `INDEX (order_id)` | 普通索引 | 查询某个订单的支付记录 |
| `INDEX (order_no)` | 普通索引 | 支付回调通过订单号查询 |
| `UNIQUE (provider, provider_trade_no)` | 唯一索引 | 防止第三方支付流水重复处理 |

说明：

- iOS App 如果销售数字会员，通常要优先考虑 Apple IAP，所以 `provider` 预留 `apple_iap`。
- 国内微信支付可以作为后续 Web、Android 或其他场景的支付渠道。

## 6. `ai_jobs` AI 任务表

用途：保存 AI 分析、参考图生成等任务状态。当前可以先不实现异步队列，但表设计先保留。

| 字段 | 类型 | 是否必填 | 说明 |
| --- | --- | --- | --- |
| `id` | `varchar(36)` | 是 | 任务 ID |
| `user_id` | `varchar(36)` | 是 | 发起用户，对应 `users.id` |
| `artwork_id` | `varchar(36)` | 否 | 对应作品 |
| `type` | `varchar(30)` | 是 | 任务类型：`analyze_artwork` / `generate_reference` |
| `status` | `varchar(20)` | 是 | 任务状态：`queued` / `running` / `success` / `failed` |
| `input_upload_id` | `varchar(36)` | 否 | 输入图片，对应 `uploads.id` |
| `output_upload_id` | `varchar(36)` | 否 | 输出图片，对应 `uploads.id` |
| `error_message` | `text` | 否 | 失败原因 |
| `started_at` | `datetime` | 否 | 开始时间 |
| `finished_at` | `datetime` | 否 | 结束时间 |
| `created_at` | `datetime` | 是 | 创建时间 |
| `updated_at` | `datetime` | 是 | 更新时间 |

建议索引：

| 索引 | 类型 | 说明 |
| --- | --- | --- |
| `PRIMARY KEY (id)` | 主键 | 按任务 ID 查询 |
| `INDEX (user_id, created_at)` | 组合索引 | 查询用户任务历史 |
| `INDEX (artwork_id)` | 普通索引 | 查询某个作品的任务 |
| `INDEX (status)` | 普通索引 | 查询排队、运行中或失败任务 |
| `INDEX (type)` | 普通索引 | 按任务类型筛选 |

任务状态流转：

```text
queued -> running -> success
queued -> running -> failed
failed -> queued
```

## 第 6 步迁移建议

迁移到 CloudBase MySQL 时，建议按这个顺序做：

1. 准备 CloudBase 环境，例如 `apps-prod`。
2. 开通 CloudBase MySQL。
3. 执行 `backend/db/init.sql` 创建基础表结构。
4. 在后端新增 MySQL repository，但保持 service 层方法名尽量不变。
5. 先迁移 `users`、`uploads`、`artworks` 三张表。
6. 确认旧接口仍然可用，再加入 `membership_orders`、`payments`、`ai_jobs`。
7. 为开发环境准备少量种子数据，方便 Flutter 真机联调。

## 暂不做的事

- 暂不把 AI 点评拆成很多细表。现阶段用 `critique_json` 保存完整结构更灵活。
- 暂不实现复杂订阅系统。当前只保留 `free` / `pro` 和到期时间。
- 暂不删除本地 JSON 存储。迁移期可以保留 JSON repository 和 MySQL repository 两套实现，靠环境变量切换。
- 暂不把语渡的云函数或 CloudBase 环境混进 CrtMu。CrtMu 后续应使用独立环境，例如 `crtmu-dev` 和 `crtmu-prod`。
