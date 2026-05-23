import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';
import test, { after } from 'node:test';

let originalCwd;
let tempCwd;
let modulesPromise;

function loadModules() {
  modulesPromise ??= (async () => {
    originalCwd = process.cwd();
    tempCwd = await mkdtemp(path.join(os.tmpdir(), 'crtmu-membership-'));
    process.chdir(tempCwd);

    const [
      artworkService,
      artworkRepository,
      userService,
    ] = await Promise.all([
      import('../src/services/artwork-service.js'),
      import('../src/repositories/artwork-repository.js'),
      import('../src/services/user-service.js'),
    ]);

    return {
      ...artworkService,
      ...artworkRepository,
      ...userService,
    };
  })();

  return modulesPromise;
}

after(async () => {
  if (originalCwd) {
    process.chdir(originalCwd);
  }

  if (tempCwd) {
    await rm(tempCwd, { recursive: true, force: true });
  }
});

function buildArtwork({ id, userId, generationStatus }) {
  return {
    id,
    userId,
    uploadId: null,
    title: 'Still life study',
    imageUrl: `https://example.test/${id}.jpg`,
    studentNote: '',
    createdAt: '2026-05-23T00:00:00.000Z',
    critique: {
      summary: 'Keep improving the composition.',
      scores: {
        composition: 70,
        shape: 70,
        color: 70,
        light: 70,
      },
      strengths: [],
      weaknesses: [],
      revisionSuggestions: [],
      nextExercise: '',
      tags: [],
      referencePrompt: 'Generate a stronger teaching reference image.',
    },
    generation: {
      status: generationStatus,
      requiredTier: 'pro',
      prompt: 'Generate a stronger teaching reference image.',
    },
  };
}

test('free users cannot generate reference images', async () => {
  const {
    createArtworkRecord,
    generateReferenceImage,
    upsertUser,
  } = await loadModules();

  await upsertUser({
    userId: 'free-user',
    studentName: 'Free Student',
  });
  await createArtworkRecord(buildArtwork({
    id: 'free-artwork',
    userId: 'free-user',
    generationStatus: 'locked',
  }));

  await assert.rejects(
    () => generateReferenceImage('free-artwork'),
    (error) => {
      assert.equal(error.name, 'AppError');
      assert.equal(error.status, 403);
      assert.equal(error.details.requiredTier, 'pro');
      assert.equal(error.details.currentTier, 'free');
      return true;
    },
  );
});

test('pro users can generate reference images', async () => {
  const {
    createArtworkRecord,
    generateReferenceImage,
    updateMembership,
    upsertUser,
  } = await loadModules();

  await upsertUser({
    userId: 'pro-user',
    studentName: 'Pro Student',
  });
  await updateMembership({
    userId: 'pro-user',
    membershipTier: 'pro',
  });
  await createArtworkRecord(buildArtwork({
    id: 'pro-artwork',
    userId: 'pro-user',
    generationStatus: 'ready',
  }));

  const result = await generateReferenceImage('pro-artwork');

  assert.equal(result.artworkId, 'pro-artwork');
  assert.equal(result.status, 'completed');
  assert.equal(result.imageUrl, 'https://example.test/pro-artwork.jpg');
  assert.equal(result.prompt, 'Generate a stronger teaching reference image.');
});
