import cors from 'cors';
import express from 'express';
import multer from 'multer';
import path from 'node:path';
import { config } from './config.js';
import { AppError } from './lib/app-error.js';
import { getCloudbaseRuntimeDiagnostics } from './repositories/cloudbase/cloudbase-client.js';
import {
  analyzeArtwork,
  generateReferenceImage,
  getUserArtworks,
  requestReferenceDirection,
} from './services/artwork-service.js';
import { createTextReply } from './services/critique-service.js';
import { membershipPlans } from './services/membership-service.js';
import { buildUserProfile } from './services/profile-service.js';
import {
  imageUploadMiddleware,
  registerUpload,
  uploadsDirectory,
} from './services/upload-service.js';
import { upsertUser, updateMembership } from './services/user-service.js';

const app = express();
app.set('trust proxy', true);

// Cross-origin support matters when the same backend serves mobile, web, and tools.
app.use(cors());

// JSON is the most common language between frontend and backend APIs.
app.use(express.json({ limit: '10mb' }));
app.use('/uploads', express.static(path.resolve(uploadsDirectory)));

// A tiny request log makes debugging much easier while we are learning.
app.use((request, response, next) => {
  const now = new Date().toISOString();
  console.log(`${now} ${request.method} ${request.path}`);
  next();
});

function readOptionalString(body, fieldName) {
  const value = body?.[fieldName];
  return typeof value === 'string' ? value.trim() : '';
}

function requireString(value, fieldName) {
  const normalized = typeof value === 'string' ? value.trim() : '';
  if (!normalized) {
    throw new AppError(400, `${fieldName} is required.`);
  }

  return normalized;
}

app.get('/health', (request, response) => {
  response.json({
    ok: true,
    service: 'crtmu-backend',
    provider: config.aiProvider,
    dataStore: config.dataStore,
    modelReady: Boolean(config.arkApiKey && (config.arkTextModel || config.arkModel)),
    visionReady: Boolean(config.arkApiKey && (config.arkVisionModel || config.arkModel)),
    imageReady: Boolean(config.arkApiKey && config.arkImageModel),
    time: new Date().toISOString(),
  });
});

app.get('/debug/runtime', (request, response, next) => {
  if (!config.enableRuntimeDebug) {
    return next();
  }

  return response.json({
    ok: true,
    ...getCloudbaseRuntimeDiagnostics(),
    time: new Date().toISOString(),
  });
});

app.post('/chat', async (request, response, next) => {
  const message = readOptionalString(request.body, 'message');

  if (!message) {
    return response.status(400).json({
      ok: false,
      error: 'message is required',
    });
  }

  try {
    const reply = await createTextReply(message);

    return response.json({
      ok: true,
      provider: config.aiProvider,
      reply,
    });
  } catch (error) {
    return next(error);
  }
});

app.get('/v1/membership/plans', (request, response) => {
  response.json({
    ok: true,
    plans: membershipPlans,
  });
});

app.post('/v1/users/upsert', async (request, response, next) => {
  try {
    const user = await upsertUser({
      userId: readOptionalString(request.body, 'userId'),
      studentName: readOptionalString(request.body, 'studentName'),
    });

    return response.json({ ok: true, user });
  } catch (error) {
    return next(error);
  }
});

app.post(
  '/v1/uploads/image',
  imageUploadMiddleware.single('file'),
  async (request, response, next) => {
    try {
      const upload = await registerUpload({
        file: request.file,
        requestBaseUrl:
          config.publicBaseUrl || `${request.protocol}://${request.get('host')}`,
        userId: request.body?.userId,
      });

      return response.json({
        ok: true,
        upload,
      });
    } catch (error) {
      return next(error);
    }
  },
);

app.post('/v1/users/:userId/membership', async (request, response, next) => {
  try {
    const user = await updateMembership({
      userId: requireString(request.params.userId, 'userId'),
      membershipTier: readOptionalString(request.body, 'membershipTier'),
    });

    return response.json({ ok: true, user });
  } catch (error) {
    return next(error);
  }
});

app.get('/v1/users/:userId/profile', async (request, response, next) => {
  try {
    const profile = await buildUserProfile(request.params.userId);
    return response.json({ ok: true, profile });
  } catch (error) {
    return next(error);
  }
});

app.get('/v1/users/:userId/artworks', async (request, response, next) => {
  try {
    const artworks = await getUserArtworks(request.params.userId);
    return response.json({ ok: true, artworks });
  } catch (error) {
    return next(error);
  }
});

app.post('/v1/artworks/analyze', async (request, response, next) => {
  try {
    const input = {
      uploadId: readOptionalString(request.body, 'uploadId'),
      userId: readOptionalString(request.body, 'userId'),
      studentName: readOptionalString(request.body, 'studentName'),
      title: readOptionalString(request.body, 'title'),
      imageUrl: readOptionalString(request.body, 'imageUrl'),
      studentNote: readOptionalString(request.body, 'studentNote'),
    };

    requireString(input.userId, 'userId');
    if (!input.uploadId && !input.imageUrl) {
      throw new AppError(400, 'Either uploadId or imageUrl is required.');
    }

    const result = await analyzeArtwork({
      uploadId: input.uploadId,
      userId: input.userId,
      studentName: input.studentName,
      title: input.title,
      imageUrl: input.imageUrl,
      studentNote: input.studentNote,
    });

    return response.json({
      ok: true,
      provider: config.aiProvider,
      ...result,
    });
  } catch (error) {
    return next(error);
  }
});

app.post('/v1/artworks/:artworkId/reference-direction', async (request, response, next) => {
  try {
    const result = await requestReferenceDirection(request.params.artworkId);
    return response.json({ ok: true, result });
  } catch (error) {
    return next(error);
  }
});

app.post('/v1/artworks/:artworkId/generate-reference', async (request, response, next) => {
  try {
    const result = await generateReferenceImage(request.params.artworkId);
    return response.json({ ok: true, result });
  } catch (error) {
    return next(error);
  }
});

app.use((error, request, response, next) => {
  console.error('Unhandled backend error:', error);

  if (response.headersSent) {
    return next(error);
  }

  const status = error instanceof AppError
      ? error.status
      : error instanceof multer.MulterError
      ? 400
      : 500;
  const details = error instanceof AppError ? error.details : undefined;
  const errorMessage = error instanceof multer.MulterError
      ? error.message
      : error.message || 'Internal Server Error';

  return response.status(status).json({
    ok: false,
    error: errorMessage,
    details,
  });
});

app.listen(config.port, config.host, () => {
  console.log(`CrtMu backend is running on http://${config.host}:${config.port}`);
  console.log(`CrtMu backend provider: ${config.aiProvider}`);
});
