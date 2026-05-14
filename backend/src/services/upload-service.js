import { randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import multer from 'multer';
import { AppError } from '../lib/app-error.js';
import { readStore, withStore } from '../repositories/app-store.js';

export const uploadsDirectory = path.join(process.cwd(), 'uploads');
mkdirSync(uploadsDirectory, { recursive: true });

function normalizeExtension(filename) {
  const ext = path.extname(filename || '').toLowerCase();
  return ext || '.jpg';
}

const storage = multer.diskStorage({
  destination: (request, file, callback) => {
    callback(null, uploadsDirectory);
  },
  filename: (request, file, callback) => {
    callback(null, `${randomUUID()}${normalizeExtension(file.originalname)}`);
  },
});

function fileFilter(request, file, callback) {
  if (typeof file.mimetype === 'string' && file.mimetype.startsWith('image/')) {
    callback(null, true);
    return;
  }

  callback(new AppError(400, 'Only image uploads are supported.'));
}

export const imageUploadMiddleware = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 12 * 1024 * 1024,
  },
});

function normalizeBaseUrl(baseUrl) {
  return baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
}

export async function registerUpload({ file, requestBaseUrl, userId }) {
  if (!file) {
    throw new AppError(400, 'file is required.');
  }

  const upload = {
    id: randomUUID(),
    userId: String(userId || '').trim() || null,
    filename: file.filename,
    originalName: file.originalname,
    mimeType: file.mimetype,
    size: file.size,
    path: file.path,
    localUrl: `${normalizeBaseUrl(requestBaseUrl)}/uploads/${file.filename}`,
    createdAt: new Date().toISOString(),
  };

  await withStore(async (store) => {
    store.uploads.push(upload);
    return upload;
  });

  return upload;
}

export async function getUpload(uploadId) {
  const store = await readStore();
  const upload = store.uploads.find((item) => item.id === uploadId);
  if (!upload) {
    throw new AppError(404, `Upload not found: ${uploadId}`);
  }

  return upload;
}

export async function buildProviderImageSource({ uploadId, imageUrl }) {
  const normalizedImageUrl = String(imageUrl || '').trim();
  if (normalizedImageUrl.length > 0) {
    return {
      uploadId: null,
      displayUrl: normalizedImageUrl,
      providerUrl: normalizedImageUrl,
      mimeType: null,
    };
  }

  const normalizedUploadId = String(uploadId || '').trim();
  if (!normalizedUploadId) {
    throw new AppError(400, 'Either uploadId or imageUrl is required.');
  }

  const upload = await getUpload(normalizedUploadId);
  const fileBuffer = await readFile(upload.path);
  return {
    uploadId: upload.id,
    displayUrl: upload.localUrl,
    providerUrl: `data:${upload.mimeType};base64,${fileBuffer.toString('base64')}`,
    mimeType: upload.mimeType,
  };
}
