import { randomUUID } from 'node:crypto';
import { AppError } from '../lib/app-error.js';
import {
  createArtworkRecord,
  findArtworkById,
  listArtworksByUserId,
  updateArtworkGeneration,
} from '../repositories/artwork-repository.js';
import { findUserById } from '../repositories/user-repository.js';
import { createArtworkCritique, createReferenceImage } from './critique-service.js';
import { canGenerateReference } from './membership-service.js';
import { buildUserProfile } from './profile-service.js';
import { upsertUser } from './user-service.js';

function normalizeText(value) {
  return String(value || '').trim();
}

async function getRequiredArtwork(artworkId) {
  const artwork = await findArtworkById(artworkId);
  if (!artwork) {
    throw new AppError(404, `Artwork not found: ${artworkId}`);
  }

  return artwork;
}

async function getRequiredUser(userId) {
  const user = await findUserById(userId);
  if (!user) {
    throw new AppError(404, `User not found for artwork: ${userId}`);
  }

  return user;
}

function assertCanGenerateReference(user) {
  if (canGenerateReference(user.membershipTier)) return;

  throw new AppError(
    403,
    'This feature requires Pro membership.',
    {
      requiredTier: 'pro',
      currentTier: user.membershipTier,
    },
  );
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
  const { buildProviderImageSource } = await import('./upload-service.js');
  const imageSource = await buildProviderImageSource({ uploadId, imageUrl });
  const critique = await createArtworkCritique({
    imageUrl: imageSource.providerUrl,
    displayImageUrl: imageSource.displayUrl,
    studentName: user.studentName,
    studentNote: normalizeText(studentNote),
    title: normalizeText(title),
  });

  const now = new Date().toISOString();

  const artwork = await createArtworkRecord({
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
  });

  return {
    artwork,
    profile: await buildUserProfile(normalizedUserId),
  };
}

export async function getUserArtworks(userId) {
  return listArtworksByUserId(userId);
}

export async function requestReferenceDirection(artworkId) {
  const artwork = await getRequiredArtwork(artworkId);
  const user = await getRequiredUser(artwork.userId);
  assertCanGenerateReference(user);

  const updatedArtwork = await updateArtworkGeneration(
    artwork.id,
    (generation) => ({
      ...generation,
      status: 'prompt_ready',
      requestedAt: new Date().toISOString(),
    }),
  );

  return {
    artworkId: updatedArtwork.id,
    status: updatedArtwork.generation.status,
    prompt: updatedArtwork.generation.prompt,
    note:
      'Reference image generation is not wired yet. This prompt is the next input for SeedEdit/Seedream.',
  };
}

export async function generateReferenceImage(artworkId) {
  const artwork = await getRequiredArtwork(artworkId);
  const user = await getRequiredUser(artwork.userId);
  assertCanGenerateReference(user);

  const startedAt = new Date().toISOString();
  let referenceImageUrl = artwork.imageUrl;

  if (artwork.uploadId) {
    const { buildProviderImageSource } = await import('./upload-service.js');
    const imageSource = await buildProviderImageSource({
      uploadId: artwork.uploadId,
      imageUrl: '',
    });
    referenceImageUrl = imageSource.providerUrl;
  }

  const generated = await createReferenceImage({
    artwork: {
      ...artwork,
      generation: {
        ...artwork.generation,
        status: 'generating',
        startedAt,
      },
    },
    referenceImageUrl,
  });

  const updatedArtwork = await updateArtworkGeneration(
    artwork.id,
    (generation) => ({
      ...generation,
      startedAt,
      status: 'completed',
      resultImageUrl: generated.imageUrl,
      note: generated.note,
      completedAt: new Date().toISOString(),
    }),
  );

  return {
    artworkId: updatedArtwork.id,
    status: updatedArtwork.generation.status,
    imageUrl: updatedArtwork.generation.resultImageUrl,
    note: updatedArtwork.generation.note,
    prompt: updatedArtwork.generation.prompt,
  };
}
