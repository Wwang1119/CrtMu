import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { AppError } from '../lib/app-error.js';

const dataDirectory = path.join(process.cwd(), 'data');
const storePath = path.join(dataDirectory, 'app-db.json');

const defaultStore = () => ({
  version: 1,
  users: [],
  artworks: [],
  uploads: [],
});

let writeChain = Promise.resolve();

async function ensureStoreFile() {
  await mkdir(dataDirectory, { recursive: true });

  try {
    await readFile(storePath, 'utf8');
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    await writeFile(storePath, JSON.stringify(defaultStore(), null, 2));
  }
}

export async function readStore() {
  await ensureStoreFile();

  const raw = await readFile(storePath, 'utf8');
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') {
      throw new Error('Store root is not an object.');
    }

    return {
      version: 1,
      users: Array.isArray(parsed.users) ? parsed.users : [],
      artworks: Array.isArray(parsed.artworks) ? parsed.artworks : [],
      uploads: Array.isArray(parsed.uploads) ? parsed.uploads : [],
    };
  } catch (error) {
    throw new AppError(
      500,
      'App store is corrupted. Please inspect backend/data/app-db.json.',
      error instanceof Error ? error.message : String(error),
    );
  }
}

export async function withStore(mutator) {
  const run = writeChain.catch(() => {}).then(async () => {
    const store = await readStore();
    const result = await mutator(store);
    await writeFile(storePath, JSON.stringify(store, null, 2));
    return result;
  });

  // Keep the internal queue alive even if one write fails, otherwise every
  // later write would inherit the old rejection and appear to fail instantly.
  writeChain = run.catch(() => {});
  return run;
}
