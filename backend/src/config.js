const defaultSystemPrompt = [
  'You are CrtMu, a professional art critique assistant for teachers and students.',
  'Your tone is warm, supportive, and specific.',
  'When the user sends text only, reply in Chinese and structure your answer in four parts:',
  '1. A short encouragement sentence.',
  '2. Clear analysis of composition, shape, color, and light.',
  '3. Three concrete revision suggestions.',
  '4. One short next-step exercise.',
  'If the user has not sent an artwork image yet, say that your current feedback is based only on text.',
].join(' ');

function readEnv(name, fallback = '') {
  const value = process.env[name];
  return typeof value === 'string' ? value.trim() : fallback;
}

function readNumberEnv(name, fallback) {
  const raw = readEnv(name);
  if (!raw) return fallback;

  const parsed = Number(raw);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export const config = {
  port: readNumberEnv('PORT', 3000),
  host: readEnv('HOST', '127.0.0.1'),
  publicBaseUrl: readEnv('PUBLIC_BASE_URL'),
  aiProvider: readEnv('AI_PROVIDER', 'mock').toLowerCase(),
  arkBaseUrl: readEnv('ARK_BASE_URL', 'https://ark.cn-beijing.volces.com/api/v3'),
  arkApiKey: readEnv('ARK_API_KEY') || readEnv('DOUBAO_API_KEY'),
  arkModel: readEnv('ARK_MODEL') || readEnv('DOUBAO_MODEL'),
  arkTextModel: readEnv('ARK_TEXT_MODEL'),
  arkVisionModel: readEnv('ARK_VISION_MODEL'),
  arkImageModel: readEnv('ARK_IMAGE_MODEL'),
  arkImageSize: readEnv('ARK_IMAGE_SIZE', '1024x1024'),
  arkImageWatermark: readEnv('ARK_IMAGE_WATERMARK', 'true').toLowerCase() !== 'false',
  arkTimeoutMs: readNumberEnv('ARK_TIMEOUT_MS', 60000),
  systemPrompt: readEnv('AI_SYSTEM_PROMPT', defaultSystemPrompt),
};
