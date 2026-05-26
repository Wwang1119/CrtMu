# CrtMu backend

This folder contains the first backend for the Flutter app.

## Why it exists

The backend sits between the Flutter app and any AI provider:

`Flutter -> backend -> AI provider`

That lets us keep API keys out of the mobile app and gives us one place to
handle logging, timeouts, uploads, and future billing logic.

## Endpoints

- `GET /health`
- `POST /chat`
- `GET /v1/membership/plans`
- `POST /v1/users/upsert`
- `POST /v1/uploads/image`
- `POST /v1/users/:userId/membership`
- `GET /v1/users/:userId/profile`
- `GET /v1/users/:userId/artworks`
- `POST /v1/artworks/analyze`
- `POST /v1/artworks/:artworkId/reference-direction`
- `POST /v1/artworks/:artworkId/generate-reference`

## Run locally

1. Copy `.env.example` to `.env`
2. Install dependencies with `npm install`
3. Start the server with `npm run dev`

For local learning, `HOST=127.0.0.1` is enough. In cloud deployment, this is
usually changed to `0.0.0.0`.

For public deployment, also set `PUBLIC_BASE_URL=https://your-domain.example`.
This keeps uploaded image URLs correct when the backend sits behind HTTPS and a reverse proxy.

## Data store

The backend keeps the old JSON file repository for local development and adds
CloudBase-native and MySQL repositories for cloud data.

- `DATA_STORE=json` uses `backend/data/app-db.json` and is the default.
- `DATA_STORE=cloudbase` uses CloudBase document database. This is the cheaper
  CloudBase-native option and does not require CloudBase Run private networking.
- `DATA_STORE=mysql` uses CloudBase MySQL through `DB_*` environment variables.

CloudBase document database example:

```env
DATA_STORE=cloudbase
CLOUDBASE_ENV_ID=yudu-web-8g1ccrez1a12fa8d
CLOUDBASE_TIMEOUT_MS=15000
CLOUDBASE_SECRETID=
CLOUDBASE_SECRETKEY=
```

When deploying to CloudBase Run, enable API key injection in the service
environment variable settings so `@cloudbase/node-sdk` can access the document
database. Create these document collections before first use:

- `users`
- `uploads`
- `artworks`

For deployment diagnostics, set `ENABLE_RUNTIME_DEBUG=true` temporarily and
call `GET /debug/runtime`. It returns only safe booleans such as whether
`CLOUDBASE_APIKEY` and the CloudBase secret pair are present, plus the selected
environment id and timeout. Turn it back off after checking the runtime.

CloudBase MySQL example:

```env
DATA_STORE=mysql
DB_HOST=172.17.0.10
DB_PORT=3306
DB_NAME=yudu-web-8g1ccrez1a12fa8d
DB_USER=crtmu_admin
DB_PASSWORD=
```

Fill `DB_PASSWORD` only in your local `.env` or CloudBase environment variables.
Do not commit a real database password. The database schema is created by
`db/init.sql`.

## Provider modes

### `AI_PROVIDER=mock`

Use this while learning the basic frontend-backend request flow. No external AI
request will be sent.

### `AI_PROVIDER=ark`

Use this when you are ready to call Doubao through the Ark runtime.

Fill these values in `.env`:

- `ARK_API_KEY`
- `ARK_TEXT_MODEL` for ordinary text chat
- `ARK_VISION_MODEL` for artwork analysis
- `ARK_IMAGE_MODEL` for reference image generation
- `ARK_MODEL` can still be used as a fallback if you want one model entry first
- `ARK_IMAGE_MODEL` (usually your SeedEdit / image generation `Endpoint ID`)
- `ARK_BASE_URL` defaults to `https://ark.cn-beijing.volces.com/api/v3`

The current implementation uses the OpenAI-compatible
`POST /chat/completions` style API and sends:

- one `system` message for the CrtMu role prompt
- one `user` message for the chat text

For artwork critique, the backend now also supports:

- `POST /v1/uploads/image` to store a local image
- `POST /v1/artworks/analyze` with either `uploadId` or `imageUrl`

During local development, uploaded files are converted into a data URL before
the image critique request is sent to the model.

Reference image generation uses a separate image model configuration and stores
the generated result URL back into the artwork archive.

For real image generation, the source image should be a public URL. In local
development, `localhost` uploads are fine for mock mode, but real Ark image
editing should eventually move to object storage.

## Next steps

Once this provider skeleton is running, we can:

1. Put in your real Ark credentials
2. Verify text chat through Doubao
3. Use `POST /v1/uploads/image` plus `POST /v1/artworks/analyze`
4. Add image generation through SeedEdit / Seedream
