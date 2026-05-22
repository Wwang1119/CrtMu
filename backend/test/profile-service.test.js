import assert from 'node:assert/strict';
import test from 'node:test';
import { buildUserProfileFromRecords } from '../src/services/profile-service.js';

test('buildUserProfileFromRecords aggregates user artwork stats', () => {
  const profile = buildUserProfileFromRecords({
    user: {
      id: 'user-1',
      studentName: '小王',
      membershipTier: 'free',
    },
    artworks: [
      {
        id: 'artwork-2',
        createdAt: '2026-05-02T00:00:00.000Z',
        critique: {
          scores: {
            composition: 80,
            shape: 70,
            color: 60,
            light: 50,
          },
          strengths: ['主体明确'],
          weaknesses: ['明暗不足'],
        },
      },
      {
        id: 'artwork-1',
        createdAt: '2026-05-01T00:00:00.000Z',
        critique: {
          scores: {
            composition: 60,
            shape: 90,
            color: 80,
            light: 70,
          },
          strengths: ['主体明确', '色彩统一'],
          weaknesses: ['明暗不足'],
        },
      },
    ],
  });

  assert.equal(profile.user.id, 'user-1');
  assert.equal(profile.stats.artworkCount, 2);
  assert.deepEqual(profile.stats.averages, {
    composition: 70,
    shape: 80,
    color: 70,
    light: 60,
  });
  assert.deepEqual(profile.recurringStrengths[0], {
    label: '主体明确',
    count: 2,
  });
  assert.deepEqual(profile.recurringWeaknesses[0], {
    label: '明暗不足',
    count: 2,
  });
});

test('buildUserProfileFromRecords handles empty users and artworks', () => {
  const profile = buildUserProfileFromRecords({
    user: null,
    artworks: [],
  });

  assert.equal(profile.user, null);
  assert.equal(profile.stats.artworkCount, 0);
  assert.deepEqual(profile.stats.averages, {
    composition: null,
    shape: null,
    color: null,
    light: null,
  });
  assert.deepEqual(profile.recentArtworks, []);
});
