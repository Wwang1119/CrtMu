import path from 'node:path';
import { execute } from './mysql-client.js';
import { fromMysqlDateTime, toMysqlDateTime } from './mysql-utils.js';
import { ensureUserExists } from './user-mysql-repository.js';

function mapUpload(row) {
  if (!row) return null;

  const filename = row.object_key;

  return {
    id: row.id,
    userId: row.user_id,
    filename,
    originalName: row.original_name ?? '',
    mimeType: row.mime_type,
    size: row.size_bytes ?? 0,
    path: path.join(process.cwd(), 'uploads', filename),
    localUrl: row.url ?? '',
    createdAt: fromMysqlDateTime(row.created_at),
  };
}

export async function createUploadRecord(upload) {
  await ensureUserExists(upload.userId);

  await execute(
    `
      INSERT INTO uploads (
        id,
        user_id,
        kind,
        object_key,
        url,
        original_name,
        mime_type,
        size_bytes,
        created_at
      )
      VALUES (?, ?, 'original', ?, ?, ?, ?, ?, ?)
    `,
    [
      upload.id,
      upload.userId || null,
      upload.filename,
      upload.localUrl,
      upload.originalName,
      upload.mimeType,
      upload.size,
      toMysqlDateTime(upload.createdAt),
    ],
  );

  return upload;
}

export async function findUploadById(uploadId) {
  const rows = await execute(
    `
      SELECT
        id,
        user_id,
        object_key,
        url,
        original_name,
        mime_type,
        size_bytes,
        created_at
      FROM uploads
      WHERE id = ? AND deleted_at IS NULL
      LIMIT 1
    `,
    [uploadId],
  );

  return mapUpload(rows[0]);
}
