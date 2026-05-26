export function toMysqlDateTime(value) {
  if (!value) return null;

  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;

  return date.toISOString().slice(0, 23).replace('T', ' ');
}

export function fromMysqlDateTime(value) {
  if (!value) return null;
  if (value instanceof Date) return value.toISOString();

  const raw = String(value).trim();
  if (!raw) return null;

  const normalized = raw.includes('T') ? raw : raw.replace(' ', 'T');
  const withTimezone = /(?:Z|[+-]\d{2}:?\d{2})$/.test(normalized)
    ? normalized
    : `${normalized}Z`;
  const date = new Date(withTimezone);

  return Number.isNaN(date.getTime()) ? raw : date.toISOString();
}

export function parseJsonColumn(value, fallback = null) {
  if (value == null) return fallback;
  if (typeof value === 'object' && !Buffer.isBuffer(value)) return value;

  const raw = Buffer.isBuffer(value) ? value.toString('utf8') : String(value);
  if (!raw) return fallback;

  try {
    return JSON.parse(raw);
  } catch {
    return fallback;
  }
}

export function stringifyJsonColumn(value) {
  return JSON.stringify(value ?? null);
}
