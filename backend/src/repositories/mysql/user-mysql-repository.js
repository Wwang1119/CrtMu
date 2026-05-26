import { execute } from './mysql-client.js';
import { fromMysqlDateTime, toMysqlDateTime } from './mysql-utils.js';

function mapUser(row) {
  if (!row) return null;

  return {
    id: row.id,
    studentName: row.student_name ?? '',
    membershipTier: row.membership_tier ?? 'free',
    createdAt: fromMysqlDateTime(row.created_at),
    updatedAt: fromMysqlDateTime(row.updated_at),
  };
}

export async function ensureUserExists(userId) {
  const normalizedUserId = String(userId || '').trim();
  if (!normalizedUserId) return;

  await execute(
    `
      INSERT IGNORE INTO users (id, membership_tier)
      VALUES (?, 'free')
    `,
    [normalizedUserId],
  );
}

export async function findUserById(userId) {
  const rows = await execute(
    `
      SELECT id, student_name, membership_tier, created_at, updated_at
      FROM users
      WHERE id = ?
      LIMIT 1
    `,
    [userId],
  );

  return mapUser(rows[0]);
}

export async function upsertUserRecord({
  userId,
  studentName,
  createDefaultName,
}) {
  const now = new Date().toISOString();
  const mysqlNow = toMysqlDateTime(now);
  const insertName = studentName || createDefaultName();

  await execute(
    `
      INSERT INTO users (
        id,
        student_name,
        membership_tier,
        created_at,
        updated_at
      )
      VALUES (?, ?, 'free', ?, ?)
      ON DUPLICATE KEY UPDATE
        student_name = CASE
          WHEN ? <> '' THEN ?
          WHEN student_name IS NULL OR student_name = '' THEN ?
          ELSE student_name
        END,
        updated_at = ?
    `,
    [
      userId,
      insertName,
      mysqlNow,
      mysqlNow,
      studentName,
      studentName,
      insertName,
      mysqlNow,
    ],
  );

  return findUserById(userId);
}

export async function updateUserMembership({ userId, membershipTier }) {
  const result = await execute(
    `
      UPDATE users
      SET membership_tier = ?, updated_at = ?
      WHERE id = ?
    `,
    [membershipTier, toMysqlDateTime(new Date()), userId],
  );

  if (result.affectedRows === 0) return null;
  return findUserById(userId);
}
