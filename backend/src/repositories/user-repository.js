import { readStore, withStore } from './app-store.js';

export async function findUserById(userId) {
  const store = await readStore();
  return store.users.find((item) => item.id === userId) ?? null;
}

export async function upsertUserRecord({
  userId,
  studentName,
  createDefaultName,
}) {
  const now = new Date().toISOString();

  return withStore(async (store) => {
    let user = store.users.find((item) => item.id === userId);

    if (!user) {
      user = {
        id: userId,
        studentName: studentName || createDefaultName(),
        membershipTier: 'free',
        createdAt: now,
        updatedAt: now,
      };
      store.users.push(user);
      return user;
    }

    if (studentName) {
      user.studentName = studentName;
    }

    user.updatedAt = now;
    return user;
  });
}

export async function updateUserMembership({ userId, membershipTier }) {
  return withStore(async (store) => {
    const user = store.users.find((item) => item.id === userId);
    if (!user) return null;

    user.membershipTier = membershipTier;
    user.updatedAt = new Date().toISOString();
    return user;
  });
}
