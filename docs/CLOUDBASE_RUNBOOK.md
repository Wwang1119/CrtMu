# CrtMu CloudBase Runbook

This note records the current low-cost CloudBase deployment path and the
production checks that proved it works. Do not put real secrets in this file.

## Current Status

As of 2026-05-25, CrtMu backend can persist current API data to CloudBase
document database with:

- CloudBase Run service: `crtmu-backend`
- CloudBase environment: `apps-prod`
- Environment ID: `yudu-web-8g1ccrez1a12fa8d`
- Data store mode: `DATA_STORE=cloudbase`
- Collections:
  - `users`
  - `uploads`
  - `artworks`

Verified endpoints:

- `GET /health` returns `ok: true` and `dataStore: "cloudbase"`.
- `POST /v1/users/upsert` returns `ok: true` for `verify_user_001`.
- `GET /v1/users/verify_user_001/profile` returns `ok: true`.
- `GET /v1/users/verify_user_001/artworks` returns `ok: true`.

## Required CloudBase Run Environment Variables

```env
HOST=0.0.0.0
PORT=3000
DATA_STORE=cloudbase
CLOUDBASE_ENV_ID=yudu-web-8g1ccrez1a12fa8d
CLOUDBASE_TIMEOUT_MS=15000
AI_PROVIDER=mock
CLOUDBASE_APIKEY=...
CLOUDBASE_SECRETID=...
CLOUDBASE_SECRETKEY=...
ENABLE_RUNTIME_DEBUG=false
```

Important:

- `CLOUDBASE_APIKEY` is the CloudBase server API key.
- `CLOUDBASE_SECRETID` and `CLOUDBASE_SECRETKEY` are the Tencent Cloud CAM
  API key pair. Prefer a sub-user key, not the main account key.
- Do not commit or screenshot real values.
- Keep `ENABLE_RUNTIME_DEBUG=false` after diagnosis.

## Root Cause Of The 2026-05-25 Timeout

The backend repeatedly failed with:

```text
CloudBase document database timed out: users.findUserById
CloudBase document database timed out: users.findUserDocumentById
```

CloudBase logs also showed:

```text
Your current request database.getDocument is longer than 3s, it may be due to the network or your query performance
```

The service had `CLOUDBASE_APIKEY`, but CloudBase's backend Node.js guide showed
SDK initialization with:

```js
secretId: process.env.CLOUDBASE_SECRETID,
secretKey: process.env.CLOUDBASE_SECRETKEY
```

After adding a CAM sub-user key pair to CloudBase Run and deploying v6, document
database reads succeeded. The key lesson: for this backend deployment,
`CLOUDBASE_APIKEY` alone was not enough; the Node SDK needed
`CLOUDBASE_SECRETID` and `CLOUDBASE_SECRETKEY`.

## Repository Behavior

The CloudBase document database repository does not use business IDs as
CloudBase `_id` values. CloudBase console does not allow manually creating keys
that start with `_`, so repository code lets CloudBase generate `_id` and stores
business IDs in the regular `id` field.

Lookup and update behavior:

- `users`: query by `id`
- `uploads`: query by `id`
- `artworks`: query by `id`
- artwork lists: query by `userId`

Recommended indexes:

- `users.id`
- `uploads.id`
- `artworks.id`
- `artworks.userId`

## Useful Verification Commands

Health:

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/health" -Method Get
```

Temporary runtime diagnostics, only when `ENABLE_RUNTIME_DEBUG=true`:

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/debug/runtime" -Method Get
```

Expected safe diagnostic values:

```text
dataStore                 : cloudbase
cloudbaseEnvId            : yudu-web-8g1ccrez1a12fa8d
cloudbaseTimeoutMs        : 15000
hasCloudbaseApiKey        : True
hasCloudbaseSecretPair    : True
```

User upsert:

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/upsert" -Method Post -ContentType "application/json" -Body '{"userId":"verify_user_001","studentName":"verify user"}'
```

Profile:

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/verify_user_001/profile" -Method Get
```

Artworks:

```powershell
Invoke-RestMethod -Uri "https://crtmu-backend-261397-4-1411825358.sh.run.tcloudbase.com/v1/users/verify_user_001/artworks" -Method Get
```

## Operational Notes

- CloudBase Run with min instances `0` can show `已暂停` and instance count `0`.
  That is auto scale-to-zero, not necessarily a crash.
- During debugging, temporarily set min instances to `1` to avoid cold-start
  noise. Set it back to `0` if cost is more important.
- The `node:20-alpine` image does not include `/bin/bash`; use `sh` in
  WebShell.
- CloudBase console `tcb/SearchClsLog` failures are log-service lookup failures,
  not proof that document writes failed.
- Experience edition document database uses shared resources. If document
  database calls become slow again even with the secret pair configured, check
  CloudBase status/logs and consider an upgraded instance before changing
  business code.

## Relationship To MySQL

The original step was named Tencent Cloud MySQL, but experience edition
CloudBase Run cannot use private network/VPC to reach the MySQL internal
address. Opening MySQL public access is not recommended.

Current practical state:

- `DATA_STORE=cloudbase` is the working low-cost cloud persistence path.
- MySQL repository code and schema can remain for a later formal deployment.
- A future MySQL switch should use standard edition/VPC or another safe private
  network path, not a public database endpoint.
