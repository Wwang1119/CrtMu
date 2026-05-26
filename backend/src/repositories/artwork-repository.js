import * as cloudbaseRepository from './cloudbase/artwork-cloudbase-repository.js';
import * as jsonRepository from './json/artwork-json-repository.js';
import * as mysqlRepository from './mysql/artwork-mysql-repository.js';
import { selectRepository } from './repository-selector.js';

function repository() {
  return selectRepository({
    cloudbaseRepository,
    jsonRepository,
    mysqlRepository,
  });
}

export async function createArtworkRecord(artwork) {
  return repository().createArtworkRecord(artwork);
}

export async function findArtworkById(artworkId) {
  return repository().findArtworkById(artworkId);
}

export async function listArtworksByUserId(userId) {
  return repository().listArtworksByUserId(userId);
}

export async function updateArtworkGeneration(artworkId, buildNextGeneration) {
  return repository().updateArtworkGeneration(artworkId, buildNextGeneration);
}
