import path from 'node:path';
import { config } from '../../config.js';
import { AppError } from '../../lib/app-error.js';
import {
  getCloudbaseApp,
  withCloudbaseTimeout,
} from './cloudbase-client.js';

function trimSlashes(value) {
  return String(value || '').replace(/^\/+|\/+$/g, '');
}

function sanitizePathSegment(value, fallback) {
  const normalized = String(value || '')
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .replace(/^_+|_+$/g, '');

  return normalized || fallback;
}

function cloudPathJoin(...segments) {
  return segments
    .map(trimSlashes)
    .filter(Boolean)
    .join('/');
}

function buildCloudPath({ uploadId, filename, userId, createdAt }) {
  const datePath = String(createdAt || new Date().toISOString())
    .slice(0, 10)
    .replaceAll('-', '/');
  const extension = path.extname(filename || '').toLowerCase() || '.jpg';

  return cloudPathJoin(
    config.cloudbaseStoragePrefix || 'uploads',
    sanitizePathSegment(userId, 'anonymous'),
    datePath,
    `${sanitizePathSegment(uploadId, 'upload')}${extension}`,
  );
}

function extractTempFileUrl(response) {
  const item = Array.isArray(response?.fileList) ? response.fileList[0] : null;
  const code = item?.code || item?.status;

  if (code && code !== 'SUCCESS' && code !== 'OK') {
    throw new AppError(
      502,
      'CloudBase storage did not return a usable temporary file URL.',
      item,
    );
  }

  return (
    item?.tempFileURL ||
    item?.download_url ||
    item?.url ||
    ''
  );
}

export async function getTemporaryFileUrl(fileId) {
  const normalizedFileId = String(fileId || '').trim();
  if (!normalizedFileId) {
    throw new AppError(500, 'CloudBase fileId is missing for uploaded image.');
  }

  const app = await getCloudbaseApp();
  const response = await withCloudbaseTimeout(
    () => app.getTempFileURL({
      fileList: [
        {
          fileID: normalizedFileId,
          maxAge: config.cloudbaseTempUrlMaxAgeSeconds,
        },
      ],
    }),
    'storage.getTempFileURL',
  );
  const url = extractTempFileUrl(response);

  if (!url) {
    throw new AppError(
      502,
      'CloudBase storage returned an empty temporary file URL.',
      response,
    );
  }

  return url;
}

export async function saveUploadFile({
  buffer,
  filename,
  mimeType,
  uploadId,
  userId,
  createdAt,
}) {
  const app = await getCloudbaseApp();
  const cloudPath = buildCloudPath({ uploadId, filename, userId, createdAt });
  const response = await withCloudbaseTimeout(
    () => app.uploadFile({
      cloudPath,
      fileContent: buffer,
    }),
    'storage.uploadFile',
  );
  const fileId = response?.fileID || response?.fileId || response?.fileid;

  if (!fileId) {
    throw new AppError(
      502,
      'CloudBase storage upload did not return fileID.',
      response,
    );
  }

  return {
    storage: 'cloudbase',
    fileId,
    cloudPath,
    path: '',
    localUrl: await getTemporaryFileUrl(fileId),
    mimeType,
  };
}

export async function buildProviderImageSource(upload) {
  const providerUrl = await getTemporaryFileUrl(upload.fileId);

  return {
    displayUrl: providerUrl,
    providerUrl,
    mimeType: upload.mimeType,
  };
}
