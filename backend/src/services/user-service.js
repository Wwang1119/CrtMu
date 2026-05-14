import { randomUUID } from 'node:crypto';
import { AppError } from '../lib/app-error.js';
import { withStore } from '../repositories/app-store.js';

export async function upsertUser({ userId, studentName }) {
  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) {
    throw new AppError(400, 'userId is required.');
  }

  const normalizedName = String(studentName || '').trim();
  const now = new Date().toISOString();

  return withStore(async (store) => {
    let user = store.users.find((item) => item.id === normalizedUserId);

    if (!user) {
      user = {
        id: normalizedUserId,
        studentName: normalizedName || `Student-${randomUUID().slice(0, 6)}`,
        membershipTier: 'free',
        createdAt: now,
        updatedAt: now,
      };
      store.users.push(user);
      return user;
    }

    if (normalizedName) {
      user.studentName = normalizedName;
    }

    user.updatedAt = now;
    return user;
  });
}

export async function updateMembership({ userId, membershipTier }) {
  const nextTier = String(membershipTier || '').trim().toLowerCase();
  if (!['free', 'pro'].includes(nextTier)) {
    throw new AppError(400, 'membershipTier must be "free" or "pro".');
  }

  return withStore(async (store) => {
    const user = store.users.find((item) => item.id === userId);
    if (!user) {
      throw new AppError(404, `User not found: ${userId}`);
    }

    user.membershipTier = nextTier;
    user.updatedAt = new Date().toISOString();
    return user;
  });
}
