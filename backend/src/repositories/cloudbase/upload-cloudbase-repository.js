import { collection, withCloudbaseTimeout } from './cloudbase-client.js';
import {
  documentId,
  firstDocument,
  normalizeDocument,
} from './cloudbase-utils.js';
import { ensureUserExists } from './user-cloudbase-repository.js';

const collectionName = 'uploads';

function uploadsCollection() {
  return collection(collectionName);
}

function mapUpload(document) {
  return normalizeDocument(document);
}

async function findUploadDocumentById(uploadId) {
  const uploads = await uploadsCollection();
  const response = await withCloudbaseTimeout(
    () => uploads
      .where({ id: uploadId })
      .limit(1)
      .get(),
    'uploads.findUploadDocumentById',
  );
  return firstDocument(response);
}

export async function createUploadRecord(upload) {
  await ensureUserExists(upload.userId);

  const uploads = await uploadsCollection();
  const existingDocumentId = documentId(await findUploadDocumentById(upload.id));
  await withCloudbaseTimeout(
    () => existingDocumentId
      ? uploads.doc(existingDocumentId).set(upload)
      : uploads.add(upload),
    'uploads.createUploadRecord',
  );
  return upload;
}

export async function findUploadById(uploadId) {
  return mapUpload(await findUploadDocumentById(uploadId));
}
