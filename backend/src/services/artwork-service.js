import { randomUUID } from 'node:crypto';
import { AppError } from '../lib/app-error.js';
import { readStore, withStore } from '../repositories/app-store.js';
import { createArtworkCritique, createReferenceImage } from './critique-service.js';
import { canGenerateReference } from './membership-service.js';
import { buildUserProfile } from './profile-service.js';
import { buildProviderImageSource } from './upload-service.js';
import { upsertUser } from './user-service.js';

function normalizeText(value) {
  return String(value || '').trim();
}

export async function analyzeArtwork({
  uploadId,
  userId,
  studentName,
  title,
  imageUrl,
  studentNote,
}) {
  const normalizedUserId = normalizeText(userId);

  if (!normalizedUserId) {
    throw new AppError(400, 'userId is required.');
  }

  const user = await upsertUser({ userId: normalizedUserId, studentName });
  const imageSource = await buildProviderImageSource({ uploadId, imageUrl });
  const critique = await createArtworkCritique({
    imageUrl: imageSource.providerUrl,
    displayImageUrl: imageSource.displayUrl,
    studentName: user.studentName,
    studentNote: normalizeText(studentNote),
    title: normalizeText(title),
  });

  const now = new Date().toISOString();

  const artwork = await withStore(async (store) => {
    const record = {
      id: randomUUID(),
      userId: normalizedUserId,
      uploadId: imageSource.uploadId,
      title: normalizeText(title) || 'Untitled artwork',
      imageUrl: imageSource.displayUrl,
      studentNote: normalizeText(studentNote),
      createdAt: now,
      critique,
      generation: {
        status: canGenerateReference(user.membershipTier) ? 'ready' : 'locked',
        requiredTier: 'pro',
        prompt: critique.referencePrompt,
      },
    };

    store.artworks.push(record);
    return record;
  });

  const store = await readStore();
  return {
    artwork,
    profile: buildUserProfile(store, normalizedUserId),
  };
}

export async function getUserArtworks(userId) {
  const store = await readStore();
  const items = store.artworks
    .filter((item) => item.userId === userId)
    .sort((left, right) => right.createdAt.localeCompare(left.createdAt));

  return items;
}

export async function requestReferenceDirection(artworkId) {
  return withStore(async (store) => {
    const artwork = store.artworks.find((item) => item.id === artworkId);
    if (!artwork) {
      throw new AppError(404, `Artwork not found: ${artworkId}`);
    }

    const user = store.users.find((item) => item.id === artwork.userId);
    if (!user) {
      throw new AppError(404, `User not found for artwork: ${artwork.userId}`);
    }

    if (!canGenerateReference(user.membershipTier)) {
      throw new AppError(
        403,
        'This feature requires Pro membership.',
        {
          requiredTier: 'pro',
          currentTier: user.membershipTier,
        },
      );
    }

    artwork.generation = {
      ...artwork.generation,
      status: 'prompt_ready',
      requestedAt: new Date().toISOString(),
    };

    return {
      artworkId: artwork.id,
      status: artwork.generation.status,
      prompt: artwork.generation.prompt,
      note:
        'Reference image generation is not wired yet. This prompt is the next input for SeedEdit/Seedream.',
    };
  });
}

export async function generateReferenceImage(artworkId) {
  return withStore(async (store) => {
    const artwork = store.artworks.find((item) => item.id === artworkId);
    if (!artwork) {
      throw new AppError(404, `Artwork not found: ${artworkId}`);
    }

    const user = store.users.find((item) => item.id === artwork.userId);
    if (!user) {
      throw new AppError(404, `User not found for artwork: ${artwork.userId}`);
    }

    if (!canGenerateReference(user.membershipTier)) {
      throw new AppError(
        403,
        'This feature requires Pro membership.',
        {
          requiredTier: 'pro',
          currentTier: user.membershipTier,
        },
      );
    }

    artwork.generation = {
      ...artwork.generation,
      status: 'generating',
      startedAt: new Date().toISOString(),
    };

    const generated = await createReferenceImage({ artwork });

    artwork.generation = {
      ...artwork.generation,
      status: 'completed',
      resultImageUrl: generated.imageUrl,
      note: generated.note,
      completedAt: new Date().toISOString(),
    };

    return {
      artworkId: artwork.id,
      status: artwork.generation.status,
      imageUrl: artwork.generation.resultImageUrl,
      note: artwork.generation.note,
      prompt: artwork.generation.prompt,
    };
  });
}
