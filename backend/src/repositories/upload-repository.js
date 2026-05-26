import * as cloudbaseRepository from './cloudbase/upload-cloudbase-repository.js';
import * as jsonRepository from './json/upload-json-repository.js';
import * as mysqlRepository from './mysql/upload-mysql-repository.js';
import { selectRepository } from './repository-selector.js';

function repository() {
  return selectRepository({
    cloudbaseRepository,
    jsonRepository,
    mysqlRepository,
  });
}

export async function createUploadRecord(upload) {
  return repository().createUploadRecord(upload);
}

export async function findUploadById(uploadId) {
  return repository().findUploadById(uploadId);
}
