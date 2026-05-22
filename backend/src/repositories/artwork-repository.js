import { readStore, withStore } from './app-store.js';

function newestFirst(left, right) {
  return right.createdAt.localeCompare(left.createdAt);
}

export async function createArtworkRecord(artwork) {
  return withStore(async (store) => {
    store.artworks.push(artwork);
    return artwork;
  });
}

export async function findArtworkById(artworkId) {
  const store = await readStore();
  return store.artworks.find((item) => item.id === artworkId) ?? null;
}

export async function listArtworksByUserId(userId) {
  const store = await readStore();
  return store.artworks
    .filter((item) => item.userId === userId)
    .sort(newestFirst);
}

export async function updateArtworkGeneration(artworkId, buildNextGeneration) {
  return withStore(async (store) => {
    const artwork = store.artworks.find((item) => item.id === artworkId);
    if (!artwork) return null;

    artwork.generation = buildNextGeneration(artwork.generation ?? {});
    return artwork;
  });
}
