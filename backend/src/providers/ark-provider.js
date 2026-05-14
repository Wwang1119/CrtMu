import { AppError } from '../lib/app-error.js';
import { extractJsonObject } from '../lib/json-utils.js';

function normalizeBaseUrl(baseUrl) {
  return baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
}

function extractTextContent(content) {
  if (typeof content === 'string') {
    return content.trim();
  }

  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part?.text === 'string') {
          return part.text;
        }

        if (typeof part?.content === 'string') {
          return part.content;
        }

        return '';
      })
      .join('\n')
      .trim();
  }

  return '';
}

async function requestArkChatCompletion({
  apiKey,
  baseUrl,
  model,
  messages,
  timeoutMs,
  temperature = 0.7,
}) {
  if (!apiKey) {
    throw new AppError(
      500,
      'ARK_API_KEY is missing. Put it in backend/.env before enabling AI_PROVIDER=ark.',
    );
  }

  if (!model) {
    throw new AppError(
      500,
      'ARK_MODEL is missing. Use your Ark endpoint ID or model ID in backend/.env.',
    );
  }

  const requestUrl = `${normalizeBaseUrl(baseUrl)}/chat/completions`;
  const payload = {
    model,
    temperature,
    messages,
  };

  console.log(`[Ark] POST ${requestUrl}`);
  console.log(`[Ark] model=${model}`);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  let response;
  try {
    response = await fetch(requestUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new AppError(
        504,
        `Ark request timed out after ${Math.round(timeoutMs / 1000)}s.`,
      );
    }

    throw new AppError(
      502,
      `Failed to reach Ark runtime: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    clearTimeout(timeout);
  }

  const responseText = await response.text();

  let json;
  try {
    json = JSON.parse(responseText);
  } catch (error) {
    throw new AppError(
      502,
      `Ark returned invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
      responseText,
    );
  }

  if (!response.ok) {
    throw new AppError(
      502,
      `Ark request failed with HTTP ${response.status} ${response.statusText}`,
      json,
    );
  }

  const reply = extractTextContent(json?.choices?.[0]?.message?.content);
  if (!reply) {
    throw new AppError(
      502,
      'Ark response did not contain choices[0].message.content.',
      json,
    );
  }

  return reply;
}

export async function createArkReply({
  apiKey,
  baseUrl,
  message,
  model,
  systemPrompt,
  timeoutMs,
}) {
  return requestArkChatCompletion({
    apiKey,
    baseUrl,
    model,
    timeoutMs,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: message },
    ],
  });
}

export async function createArkArtworkCritique({
  apiKey,
  baseUrl,
  model,
  timeoutMs,
  input,
}) {
  const systemPrompt = [
    'You are CrtMu, an expert art critique assistant.',
    'Analyze the uploaded artwork and reply with valid JSON only.',
    'Do not use markdown code fences.',
    'Return this shape exactly:',
    '{"summary":"","scores":{"composition":0,"shape":0,"color":0,"light":0},"strengths":[],"weaknesses":[],"revisionSuggestions":[],"nextExercise":"","tags":[],"referencePrompt":""}',
    'All text must be in Chinese.',
    'Scores must be integers from 0 to 100.',
    'Each array should contain 2 to 4 concise items.',
    'referencePrompt should be a strong image-edit instruction for generating a better teaching reference image based on the original artwork.',
  ].join(' ');

  const userText = [
    `作品标题：${input.title || '未命名作品'}`,
    `学生姓名：${input.studentName || '未提供'}`,
    `学生补充说明：${input.studentNote || '无'}`,
    '请从构图、造型、色彩、光影四个角度进行专业点评。',
  ].join('\n');

  const content = [
    { type: 'text', text: userText },
    { type: 'image_url', image_url: { url: input.imageUrl } },
  ];

  const raw = await requestArkChatCompletion({
    apiKey,
    baseUrl,
    model,
    timeoutMs,
    temperature: 0.3,
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content },
    ],
  });

  const critique = extractJsonObject(raw);
  return {
    summary: String(critique.summary || '').trim(),
    scores: {
      composition: Number(critique?.scores?.composition || 0),
      shape: Number(critique?.scores?.shape || 0),
      color: Number(critique?.scores?.color || 0),
      light: Number(critique?.scores?.light || 0),
    },
    strengths: Array.isArray(critique.strengths) ? critique.strengths.map(String) : [],
    weaknesses: Array.isArray(critique.weaknesses)
      ? critique.weaknesses.map(String)
      : [],
    revisionSuggestions: Array.isArray(critique.revisionSuggestions)
      ? critique.revisionSuggestions.map(String)
      : [],
    nextExercise: String(critique.nextExercise || '').trim(),
    tags: Array.isArray(critique.tags) ? critique.tags.map(String) : [],
    referencePrompt: String(critique.referencePrompt || '').trim(),
  };
}

function extractImageUrl(payload) {
  const candidates = [];

  if (Array.isArray(payload?.data)) {
    candidates.push(...payload.data);
  }

  if (Array.isArray(payload?.images)) {
    candidates.push(...payload.images);
  }

  for (const item of candidates) {
    if (typeof item?.url === 'string' && item.url.trim()) {
      return item.url.trim();
    }
    if (typeof item?.image_url === 'string' && item.image_url.trim()) {
      return item.image_url.trim();
    }
  }

  if (typeof payload?.url === 'string' && payload.url.trim()) {
    return payload.url.trim();
  }

  return '';
}

function ensurePublicImageUrl(url) {
  const value = String(url || '').trim();
  if (!value) {
    throw new AppError(400, 'Reference image URL is empty.');
  }

  if (value.startsWith('http://127.0.0.1') || value.startsWith('http://localhost')) {
    throw new AppError(
      400,
      'Real Ark image generation needs a public image URL. Localhost images only work in mock mode.',
    );
  }

  return value;
}

export async function createArkReferenceImage({
  apiKey,
  baseUrl,
  imageModel,
  prompt,
  referenceImageUrl,
  timeoutMs,
  imageSize,
  watermark,
}) {
  if (!imageModel) {
    throw new AppError(
      500,
      'ARK_IMAGE_MODEL is missing. Put the SeedEdit / image model endpoint ID in backend/.env.',
    );
  }

  const requestUrl = `${normalizeBaseUrl(baseUrl)}/images/generations`;
  const payload = {
    model: imageModel,
    prompt,
    image: ensurePublicImageUrl(referenceImageUrl),
    size: imageSize,
    response_format: 'url',
    watermark,
  };

  console.log(`[Ark] POST ${requestUrl}`);
  console.log(`[Ark] imageModel=${imageModel}`);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  let response;
  try {
    response = await fetch(requestUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new AppError(
        504,
        `Ark image generation timed out after ${Math.round(timeoutMs / 1000)}s.`,
      );
    }

    throw new AppError(
      502,
      `Failed to reach Ark image runtime: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    clearTimeout(timeout);
  }

  const responseText = await response.text();
  let json;
  try {
    json = JSON.parse(responseText);
  } catch (error) {
    throw new AppError(
      502,
      `Ark image generation returned invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
      responseText,
    );
  }

  if (!response.ok) {
    throw new AppError(
      502,
      `Ark image generation failed with HTTP ${response.status} ${response.statusText}`,
      json,
    );
  }

  const imageUrl = extractImageUrl(json);
  if (!imageUrl) {
    throw new AppError(
      502,
      'Ark image generation did not contain an output URL.',
      json,
    );
  }

  return {
    imageUrl,
    note: '参考图已生成。',
  };
}
