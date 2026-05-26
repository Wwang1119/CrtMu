import { config } from '../../config.js';
import { AppError } from '../../lib/app-error.js';

let poolPromise;

function assertMysqlConfig() {
  const missing = [];

  if (!config.db.host) missing.push('DB_HOST');
  if (!config.db.name) missing.push('DB_NAME');
  if (!config.db.user) missing.push('DB_USER');
  if (!config.db.password) missing.push('DB_PASSWORD');

  if (missing.length > 0) {
    throw new AppError(
      500,
      `MySQL data store is enabled, but ${missing.join(', ')} is not configured.`,
    );
  }
}

async function createPool() {
  assertMysqlConfig();

  let mysql;
  try {
    mysql = await import('mysql2/promise');
  } catch (error) {
    throw new AppError(
      500,
      'MySQL data store requires the mysql2 package. Run npm install in backend/.',
      error instanceof Error ? error.message : String(error),
    );
  }

  return mysql.createPool({
    host: config.db.host,
    port: config.db.port,
    database: config.db.name,
    user: config.db.user,
    password: config.db.password,
    waitForConnections: true,
    connectionLimit: 10,
    charset: 'utf8mb4',
    timezone: 'Z',
    dateStrings: true,
  });
}

export async function getMysqlPool() {
  poolPromise ??= createPool();
  return poolPromise;
}

export async function execute(sql, params = []) {
  const pool = await getMysqlPool();
  const [result] = await pool.execute(sql, params);
  return result;
}
