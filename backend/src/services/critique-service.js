import { config } from '../config.js';
import { AppError } from '../lib/app-error.js';
import {
  createArkArtworkCritique,
  createArkReferenceImage,
  createArkReply,
} from '../providers/ark-provider.js';
import {
  createMockArtworkCritique,
  createMockReferenceImage,
  createMockReply,
} from '../providers/mock-provider.js';

export async function createTextReply(message) {
  const textModel = config.arkTextModel || config.arkModel;

  switch (config.aiProvider) {
    case 'mock':
      return createMockReply({ message });
    case 'ark':
    case 'doubao':
      return createArkReply({
        apiKey: config.arkApiKey,
        baseUrl: config.arkBaseUrl,
        message,
        model: textModel,
        systemPrompt: config.systemPrompt,
        timeoutMs: config.arkTimeoutMs,
      });
    default:
      throw new AppError(
        500,
        `Unsupported AI_PROVIDER: ${config.aiProvider}. Use "mock" or "ark".`,
      );
  }
}

export async function createArtworkCritique(input) {
  const visionModel = config.arkVisionModel || config.arkModel;

  switch (config.aiProvider) {
    case 'mock':
      return createMockArtworkCritique(input);
    case 'ark':
    case 'doubao':
      return createArkArtworkCritique({
        apiKey: config.arkApiKey,
        baseUrl: config.arkBaseUrl,
        model: visionModel,
        timeoutMs: config.arkTimeoutMs,
        input,
      });
    default:
      throw new AppError(
        500,
        `Unsupported AI_PROVIDER: ${config.aiProvider}. Use "mock" or "ark".`,
      );
  }
}

export async function createReferenceImage({ artwork, referenceImageUrl }) {
  switch (config.aiProvider) {
    case 'mock':
      return createMockReferenceImage({ artwork });
    case 'ark':
    case 'doubao':
      return createArkReferenceImage({
        apiKey: config.arkApiKey,
        baseUrl: config.arkBaseUrl,
        imageModel: config.arkImageModel,
        prompt: artwork.generation.prompt,
        referenceImageUrl: referenceImageUrl || artwork.imageUrl,
        timeoutMs: config.arkTimeoutMs,
        imageSize: config.arkImageSize,
        watermark: config.arkImageWatermark,
      });
    default:
      throw new AppError(
        500,
        `Unsupported AI_PROVIDER: ${config.aiProvider}. Use "mock" or "ark".`,
      );
  }
}
