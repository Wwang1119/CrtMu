import { randomUUID } from 'node:crypto';
import { AppError } from '../lib/app-error.js';
import {
  updateUserMembership,
  upsertUserRecord,
} from '../repositories/user-repository.js';

export async function upsertUser({ userId, studentName }) {
  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) {
    throw new AppError(400, 'userId is required.');
  }

  const normalizedName = String(studentName || '').trim();

  return upsertUserRecord({
    userId: normalizedUserId,
    studentName: normalizedName,
    createDefaultName: () => `Student-${randomUUID().slice(0, 6)}`,
  });
}

export async function updateMembership({ userId, membershipTier }) {
  const nextTier = String(membershipTier || '').trim().toLowerCase();
  if (!['free', 'pro'].includes(nextTier)) {
    throw new AppError(400, 'membershipTier must be "free" or "pro".');
  }

  const user = await updateUserMembership({
    userId,
    membershipTier: nextTier,
  });
  if (!user) {
    throw new AppError(404, `User not found: ${userId}`);
  }

  return user;
}
