import * as cloudbaseRepository from './cloudbase/user-cloudbase-repository.js';
import * as jsonRepository from './json/user-json-repository.js';
import * as mysqlRepository from './mysql/user-mysql-repository.js';
import { selectRepository } from './repository-selector.js';

function repository() {
  return selectRepository({
    cloudbaseRepository,
    jsonRepository,
    mysqlRepository,
  });
}

export async function findUserById(userId) {
  return repository().findUserById(userId);
}

export async function upsertUserRecord(input) {
  return repository().upsertUserRecord(input);
}

export async function updateUserMembership(input) {
  return repository().updateUserMembership(input);
}
