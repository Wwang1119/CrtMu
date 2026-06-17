import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

export function getLocalUploadsDirectory() {
  return path.join(process.cwd(), 'uploads');
}

export const localUploadsDirectory = getLocalUploadsDirectory();

function normalizeBaseUrl(baseUrl) {
  return baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
}

export async function saveUploadFile({ buffer, filename, requestBaseUrl }) {
  const uploadsDirectory = getLocalUploadsDirectory();
  await mkdir(uploadsDirectory, { recursive: true });

  const localPath = path.join(uploadsDirectory, filename);
  await writeFile(localPath, buffer);

  return {
    storage: 'local',
    fileId: null,
    cloudPath: null,
    path: localPath,
    localUrl: `${normalizeBaseUrl(requestBaseUrl)}/uploads/${filename}`,
  };
}

export async function buildProviderImageSource(upload) {
  const fileBuffer = await readFile(upload.path);

  return {
    displayUrl: upload.localUrl,
    providerUrl: `data:${upload.mimeType};base64,${fileBuffer.toString('base64')}`,
    mimeType: upload.mimeType,
  };
}
