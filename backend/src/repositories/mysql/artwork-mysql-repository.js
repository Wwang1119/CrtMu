import { execute } from './mysql-client.js';
import {
  fromMysqlDateTime,
  parseJsonColumn,
  stringifyJsonColumn,
  toMysqlDateTime,
} from './mysql-utils.js';

function mapArtwork(row) {
  if (!row) return null;

  return {
    id: row.id,
    userId: row.user_id,
    uploadId: row.cover_upload_id,
    title: row.title ?? 'Untitled artwork',
    imageUrl: row.image_url ?? '',
    studentNote: row.description ?? '',
    createdAt: fromMysqlDateTime(row.created_at),
    critique: parseJsonColumn(row.critique_json, {}),
    generation: parseJsonColumn(row.generation_json, {}),
  };
}

export async function createArtworkRecord(artwork) {
  await execute(
    `
      INSERT INTO artworks (
        id,
        user_id,
        title,
        description,
        status,
        cover_upload_id,
        image_url,
        critique_json,
        generation_json,
        analysis_summary,
        created_at,
        updated_at
      )
      VALUES (?, ?, ?, ?, 'done', ?, ?, ?, ?, ?, ?, ?)
    `,
    [
      artwork.id,
      artwork.userId,
      artwork.title,
      artwork.studentNote,
      artwork.uploadId || null,
      artwork.imageUrl,
      stringifyJsonColumn(artwork.critique),
      stringifyJsonColumn(artwork.generation),
      artwork.critique?.summary ?? null,
      toMysqlDateTime(artwork.createdAt),
      toMysqlDateTime(artwork.createdAt),
    ],
  );

  if (artwork.uploadId) {
    await execute(
      `
        UPDATE uploads
        SET artwork_id = ?
        WHERE id = ?
      `,
      [artwork.id, artwork.uploadId],
    );
  }

  return artwork;
}

export async function findArtworkById(artworkId) {
  const rows = await execute(
    `
      SELECT
        id,
        user_id,
        cover_upload_id,
        title,
        description,
        image_url,
        critique_json,
        generation_json,
        created_at
      FROM artworks
      WHERE id = ? AND deleted_at IS NULL
      LIMIT 1
    `,
    [artworkId],
  );

  return mapArtwork(rows[0]);
}

export async function listArtworksByUserId(userId) {
  const rows = await execute(
    `
      SELECT
        id,
        user_id,
        cover_upload_id,
        title,
        description,
        image_url,
        critique_json,
        generation_json,
        created_at
      FROM artworks
      WHERE user_id = ? AND deleted_at IS NULL
      ORDER BY created_at DESC
    `,
    [userId],
  );

  return rows.map(mapArtwork);
}

export async function updateArtworkGeneration(artworkId, buildNextGeneration) {
  const artwork = await findArtworkById(artworkId);
  if (!artwork) return null;

  const nextGeneration = buildNextGeneration(artwork.generation ?? {});

  await execute(
    `
      UPDATE artworks
      SET generation_json = ?
      WHERE id = ?
    `,
    [stringifyJsonColumn(nextGeneration), artworkId],
  );

  return {
    ...artwork,
    generation: nextGeneration,
  };
}
