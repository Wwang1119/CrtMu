import assert from 'node:assert/strict';
import { access, mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test from 'node:test';
import {
  buildProviderImageSource,
  saveUploadFile,
} from '../src/repositories/local/upload-file-local-repository.js';

test('local upload file repository writes files and builds data URLs', async () => {
  const originalCwd = process.cwd();
  const tempCwd = await mkdtemp(path.join(os.tmpdir(), 'crtmu-upload-local-'));

  try {
    process.chdir(tempCwd);

    const stored = await saveUploadFile({
      buffer: Buffer.from('image-bytes'),
      filename: 'upload-1.jpg',
      requestBaseUrl: 'http://127.0.0.1:3000',
    });

    assert.equal(stored.storage, 'local');
    assert.equal(stored.fileId, null);
    assert.equal(stored.cloudPath, null);
    assert.equal(path.dirname(stored.path), path.join(tempCwd, 'uploads'));
    assert.equal(stored.localUrl, 'http://127.0.0.1:3000/uploads/upload-1.jpg');
    await access(stored.path);

    const source = await buildProviderImageSource({
      path: stored.path,
      localUrl: stored.localUrl,
      mimeType: 'image/jpeg',
    });

    assert.equal(source.displayUrl, stored.localUrl);
    assert.equal(source.mimeType, 'image/jpeg');
    assert.match(source.providerUrl, /^data:image\/jpeg;base64,/);
  } finally {
    process.chdir(originalCwd);
    await rm(tempCwd, { recursive: true, force: true });
  }
});
