import { randomUUID } from 'node:crypto';
import path from 'node:path';
import multer from 'multer';
import { AppError } from '../lib/app-error.js';
import {
  createUploadRecord,
  findUploadById,
} from '../repositories/upload-repository.js';
import {
  buildProviderImageSource as buildStoredFileProviderImageSource,
  saveUploadFile,
  uploadsDirectory,
} from '../repositories/upload-file-repository.js';

export { uploadsDirectory };

function normalizeExtension(filename) {
  const ext = path.extname(filename || '').toLowerCase();
  return ext || '.jpg';
}

function fileFilter(request, file, callback) {
  if (typeof file.mimetype === 'string' && file.mimetype.startsWith('image/')) {
    callback(null, true);
    return;
  }

  callback(new AppError(400, 'Only image uploads are supported.'));
}

export const imageUploadMiddleware = multer({
  storage: multer.memoryStorage(),
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

  if (!file.buffer) {
    throw new AppError(400, 'Uploaded file buffer is missing.');
  }

  const uploadId = randomUUID();
  const createdAt = new Date().toISOString();
  const filename = `${uploadId}${normalizeExtension(file.originalname)}`;
  const normalizedUserId = String(userId || '').trim() || null;
  const storedFile = await saveUploadFile({
    buffer: file.buffer,
    filename,
    mimeType: file.mimetype,
    uploadId,
    userId: normalizedUserId,
    createdAt,
    requestBaseUrl: normalizeBaseUrl(requestBaseUrl),
  });

  const upload = {
    id: uploadId,
    userId: normalizedUserId,
    filename,
    originalName: file.originalname,
    mimeType: file.mimetype,
    size: file.size,
    storage: storedFile.storage,
    fileId: storedFile.fileId,
    cloudPath: storedFile.cloudPath,
    path: storedFile.path,
    localUrl: storedFile.localUrl,
    createdAt,
  };

  return createUploadRecord(upload);
}

export async function getUpload(uploadId) {
  const upload = await findUploadById(uploadId);
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
  const storedFileSource = await buildStoredFileProviderImageSource(upload);
  return {
    uploadId: upload.id,
    displayUrl: storedFileSource.displayUrl,
    providerUrl: storedFileSource.providerUrl,
    mimeType: storedFileSource.mimeType,
  };
}
