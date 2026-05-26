import { collection, withCloudbaseTimeout } from './cloudbase-client.js';
import {
  documentId,
  firstDocument,
  normalizeDocument,
} from './cloudbase-utils.js';

const collectionName = 'users';

function usersCollection() {
  return collection(collectionName);
}

function mapUser(document) {
  const user = normalizeDocument(document);
  if (!user) return null;

  return {
    id: user.id,
    studentName: user.studentName ?? '',
    membershipTier: user.membershipTier ?? 'free',
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

async function findUserDocumentById(userId) {
  const users = await usersCollection();
  const response = await withCloudbaseTimeout(
    () => users
      .where({ id: userId })
      .limit(1)
      .get(),
    'users.findUserDocumentById',
  );
  return firstDocument(response);
}

async function saveUserRecord(users, existingDocument, user, label) {
  const existingDocumentId = documentId(existingDocument);
  await withCloudbaseTimeout(
    () => existingDocumentId
      ? users.doc(existingDocumentId).set(user)
      : users.add(user),
    label,
  );
}

export async function ensureUserExists(userId) {
  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) return;

  const existingDocument = await findUserDocumentById(normalizedUserId);
  if (existingDocument) return;

  const now = new Date().toISOString();
  const users = await usersCollection();
  await saveUserRecord(
    users,
    null,
    {
      id: normalizedUserId,
      studentName: '',
      membershipTier: 'free',
      createdAt: now,
      updatedAt: now,
    },
    'users.ensureUserExists',
  );
}

export async function findUserById(userId) {
  return mapUser(await findUserDocumentById(userId));
}

export async function upsertUserRecord({
  userId,
  studentName,
  createDefaultName,
}) {
  const now = new Date().toISOString();
  const users = await usersCollection();
  const existingDocument = await findUserDocumentById(userId);
  const existing = mapUser(existingDocument);

  const user = {
    id: userId,
    studentName:
      studentName || existing?.studentName || createDefaultName(),
    membershipTier: existing?.membershipTier ?? 'free',
    createdAt: existing?.createdAt ?? now,
    updatedAt: now,
  };

  await saveUserRecord(
    users,
    existingDocument,
    user,
    'users.upsertUserRecord',
  );
  return user;
}

export async function updateUserMembership({ userId, membershipTier }) {
  const existingDocument = await findUserDocumentById(userId);
  const user = mapUser(existingDocument);
  if (!user) return null;

  const nextUser = {
    ...user,
    membershipTier,
    updatedAt: new Date().toISOString(),
  };

  const users = await usersCollection();
  await saveUserRecord(
    users,
    existingDocument,
    nextUser,
    'users.updateUserMembership',
  );
  return nextUser;
}
