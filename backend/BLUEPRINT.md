# CrtMu backend blueprint

This file explains the first real backend slice for the product.

## Core entities

### User

- `id`
- `studentName`
- `membershipTier`
- `createdAt`
- `updatedAt`

### Artwork

- `id`
- `userId`
- `title`
- `imageUrl`
- `studentNote`
- `createdAt`
- `critique`
- `generation`

### Critique

- `summary`
- `scores.composition`
- `scores.shape`
- `scores.color`
- `scores.light`
- `strengths`
- `weaknesses`
- `revisionSuggestions`
- `nextExercise`
- `tags`
- `referencePrompt`

## Why this shape

This mirrors the product idea closely:

- free users can get critique + archive
- the archive gives long-term comparison
- pro users can unlock `referencePrompt`, which is the bridge to future image generation

## API flow

1. Flutter uploads the image and gets an `uploadId`
2. Flutter calls `POST /v1/artworks/analyze`
3. Backend resolves the uploaded file into a model-friendly image source
4. Backend asks the provider for a structured critique
5. Backend stores the result in the user archive
6. Flutter reads `GET /v1/users/:userId/profile` for progress summaries
7. Pro users call `POST /v1/artworks/:artworkId/reference-direction`
8. Pro users call `POST /v1/artworks/:artworkId/generate-reference`

## Current storage choice

The default local implementation uses `backend/data/app-db.json`. The repository
layer also includes CloudBase document database and MySQL adapters selected by
`DATA_STORE`; see [README.md](README.md) for configuration. The entity mapping is:

- `users[]` -> `users` table
- `artworks[]` -> `artworks` table
- `uploads[]` -> `uploads` table
- derived profile -> API aggregation layer
