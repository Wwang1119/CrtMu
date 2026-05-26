export function firstDocument(response) {
  const data = response?.data;
  return Array.isArray(data) ? data[0] ?? null : null;
}

export function documentId(document) {
  const value = document?._id;
  return typeof value === 'string' ? value : '';
}

export function normalizeDocument(document) {
  if (!document) return null;
  const { _id, ...rest } = document;
  return rest;
}
