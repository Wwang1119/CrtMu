import { config } from '../config.js';
import { AppError } from '../lib/app-error.js';
import * as cloudbaseRepository from './cloudbase/upload-file-cloudbase-repository.js';
import * as localRepository from './local/upload-file-local-repository.js';

export const uploadsDirectory = localRepository.localUploadsDirectory;

function resolveUploadStorage() {
  if (config.uploadStorage === 'auto') {
    return config.dataStore === 'cloudbase' ? 'cloudbase' : 'local';
  }

  return config.uploadStorage;
}

export function getUploadStorageMode() {
  return resolveUploadStorage();
}

function repository() {
  switch (resolveUploadStorage()) {
    case 'cloudbase':
      return cloudbaseRepository;
    case 'local':
      return localRepository;
    default:
      throw new AppError(
        500,
        `Unsupported UPLOAD_STORAGE: ${config.uploadStorage}. Use "auto", "local", or "cloudbase".`,
      );
  }
}

function repositoryForUpload(upload) {
  if (upload?.storage === 'cloudbase' || upload?.fileId) {
    return cloudbaseRepository;
  }

  if (upload?.storage === 'local' || upload?.path) {
    return localRepository;
  }

  return repository();
}

export async function saveUploadFile(input) {
  return repository().saveUploadFile(input);
}

export async function buildProviderImageSource(upload) {
  return repositoryForUpload(upload).buildProviderImageSource(upload);
}
