import { readStore, withStore } from '../app-store.js';

export async function createUploadRecord(upload) {
  return withStore(async (store) => {
    store.uploads.push(upload);
    return upload;
  });
}

export async function findUploadById(uploadId) {
  const store = await readStore();
  return store.uploads.find((item) => item.id === uploadId) ?? null;
}
