import { listArtworksByUserId } from '../repositories/artwork-repository.js';
import { findUserById } from '../repositories/user-repository.js';

function averageScore(items) {
  if (!items.length) return null;
  return Math.round(items.reduce((sum, item) => sum + item, 0) / items.length);
}

function countValues(values) {
  const counts = new Map();
  for (const value of values) {
    const key = String(value || '').trim();
    if (!key) continue;
    counts.set(key, (counts.get(key) || 0) + 1);
  }

  return [...counts.entries()]
    .sort((left, right) => right[1] - left[1])
    .map(([label, count]) => ({ label, count }));
}

export function buildUserProfileFromRecords({ user, artworks }) {
  const compositionScores = artworks
    .map((item) => item.critique?.scores?.composition)
    .filter((value) => typeof value === 'number');
  const shapeScores = artworks
    .map((item) => item.critique?.scores?.shape)
    .filter((value) => typeof value === 'number');
  const colorScores = artworks
    .map((item) => item.critique?.scores?.color)
    .filter((value) => typeof value === 'number');
  const lightScores = artworks
    .map((item) => item.critique?.scores?.light)
    .filter((value) => typeof value === 'number');

  const strengthCounts = countValues(
    artworks.flatMap((item) => item.critique?.strengths ?? []),
  ).slice(0, 5);
  const weaknessCounts = countValues(
    artworks.flatMap((item) => item.critique?.weaknesses ?? []),
  ).slice(0, 5);

  return {
    user: user ?? null,
    stats: {
      artworkCount: artworks.length,
      averages: {
        composition: averageScore(compositionScores),
        shape: averageScore(shapeScores),
        color: averageScore(colorScores),
        light: averageScore(lightScores),
      },
    },
    recurringStrengths: strengthCounts,
    recurringWeaknesses: weaknessCounts,
    recentArtworks: artworks.slice(0, 10),
  };
}

export async function buildUserProfile(userId) {
  const [user, artworks] = await Promise.all([
    findUserById(userId),
    listArtworksByUserId(userId),
  ]);

  return buildUserProfileFromRecords({ user, artworks });
}
