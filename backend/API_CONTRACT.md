# CrtMu Backend API Contract

This file is the stable agreement between the Flutter client and the Node backend.
Keep endpoint paths compatible unless a future versioned API is introduced.

## Common response shape

Successful responses include:

```json
{
  "ok": true
}
```

Error responses include:

```json
{
  "ok": false,
  "error": "Human-readable error message",
  "details": {}
}
```

`details` is optional and may be omitted.

## `POST /chat`

Request:

```json
{
  "message": "请点评这幅画的构图"
}
```

Response:

```json
{
  "ok": true,
  "provider": "mock",
  "reply": "..."
}
```

## `POST /v1/uploads/image`

Request: `multipart/form-data`

- `file`: image file, required
- `userId`: string, optional

Response:

```json
{
  "ok": true,
  "upload": {
    "id": "upload-id",
    "localUrl": "http://host/uploads/file.jpg"
  }
}
```

The upload object may include additional metadata, but Flutter currently relies
only on `id` and `localUrl`.

## `POST /v1/artworks/analyze`

Request:

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

Rules:

- `userId` is required.
- Either `uploadId` or `imageUrl` is required.
- `studentName`, `title`, and `studentNote` are optional strings.

Response:

```json
{
  "ok": true,
  "provider": "mock",
  "artwork": {
    "id": "artwork-id",
    "generation": {
      "status": "locked"
    },
    "critique": {
      "summary": "...",
      "scores": {
        "composition": 80,
        "shape": 70,
        "color": 66,
        "light": 60
      },
      "strengths": [],
      "weaknesses": [],
      "revisionSuggestions": [],
      "nextExercise": ""
    }
  }
}
```

Flutter currently depends on `artwork.id`, `artwork.generation.status`, and the
fields inside `artwork.critique`.

## `POST /v1/artworks/:artworkId/generate-reference`

Response:

```json
{
  "ok": true,
  "result": {
    "artworkId": "artwork-id",
    "status": "completed",
    "imageUrl": "https://example.com/reference.png",
    "note": "参考图已生成。"
  }
}
```
