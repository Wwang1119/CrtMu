import { config } from '../config.js';
import { AppError } from '../lib/app-error.js';

export function selectRepository({
  cloudbaseRepository,
  jsonRepository,
  mysqlRepository,
}) {
  switch (config.dataStore) {
    case 'cloudbase':
      return cloudbaseRepository;
    case 'json':
      return jsonRepository;
    case 'mysql':
      return mysqlRepository;
    default:
      throw new AppError(
        500,
        `Unsupported DATA_STORE: ${config.dataStore}. Use "json", "mysql", or "cloudbase".`,
      );
  }
}
