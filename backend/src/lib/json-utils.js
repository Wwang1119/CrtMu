import { AppError } from './app-error.js';

export function safeJsonParse(raw, fallbackErrorMessage) {
  try {
    return JSON.parse(raw);
  } catch (error) {
    throw new AppError(
      502,
      fallbackErrorMessage,
      error instanceof Error ? error.message : String(error),
    );
  }
}

export function extractJsonObject(rawText) {
  const direct = rawText.trim();
  if (direct.startsWith('{') && direct.endsWith('}')) {
    return safeJsonParse(direct, 'Model returned invalid JSON.');
  }

  const fenced = direct.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    return safeJsonParse(fenced[1].trim(), 'Model returned invalid fenced JSON.');
  }

  const start = direct.indexOf('{');
  const end = direct.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return safeJsonParse(
      direct.slice(start, end + 1),
      'Model returned invalid embedded JSON.',
    );
  }

  throw new AppError(502, 'Model response did not contain a JSON object.', rawText);
}
