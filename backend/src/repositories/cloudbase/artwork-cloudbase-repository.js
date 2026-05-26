import { collection, withCloudbaseTimeout } from './cloudbase-client.js';
import {
  documentId,
  firstDocument,
  normalizeDocument,
} from './cloudbase-utils.js';

const collectionName = 'artworks';

function artworksCollection() {
  return collection(collectionName);
}

function mapArtwork(document) {
  return normalizeDocument(document);
}

async function findArtworkDocumentById(artworkId) {
  const artworks = await artworksCollection();
  const response = await withCloudbaseTimeout(
    () => artworks
      .where({ id: artworkId })
      .limit(1)
      .get(),
    'artworks.findArtworkDocumentById',
  );
  return firstDocument(response);
}

export async function createArtworkRecord(artwork) {
  const artworks = await artworksCollection();
  const existingDocumentId = documentId(await findArtworkDocumentById(artwork.id));
  await withCloudbaseTimeout(
    () => existingDocumentId
      ? artworks.doc(existingDocumentId).set(artwork)
      : artworks.add(artwork),
    'artworks.createArtworkRecord',
  );
  return artwork;
}

export async function findArtworkById(artworkId) {
  return mapArtwork(await findArtworkDocumentById(artworkId));
}

export async function listArtworksByUserId(userId) {
  const artworks = await artworksCollection();
  const response = await withCloudbaseTimeout(
    () => artworks
      .where({ userId })
      .orderBy('createdAt', 'desc')
      .get(),
    'artworks.listArtworksByUserId',
  );

  return (response?.data ?? []).map(mapArtwork);
}

export async function updateArtworkGeneration(artworkId, buildNextGeneration) {
  const existingDocument = await findArtworkDocumentById(artworkId);
  const artwork = mapArtwork(existingDocument);
  if (!artwork) return null;

  const nextArtwork = {
    ...artwork,
    generation: buildNextGeneration(artwork.generation ?? {}),
  };

  const artworks = await artworksCollection();
  const existingDocumentId = documentId(existingDocument);
  await withCloudbaseTimeout(
    () => artworks.doc(existingDocumentId).set(nextArtwork),
    'artworks.updateArtworkGeneration',
  );
  return nextArtwork;
}
