import { config } from '../../config.js';
import { AppError } from '../../lib/app-error.js';

let databasePromise;

function readSecretEnv(name) {
  const value = process.env[name];
  return typeof value === 'string' ? value.trim() : '';
}

function hasTencentCloudSecretPair() {
  return Boolean(
    readSecretEnv('TENCENTCLOUD_SECRETID') &&
    readSecretEnv('TENCENTCLOUD_SECRETKEY'),
  );
}

function hasCloudbaseSecretPair() {
  return Boolean(
    readSecretEnv('CLOUDBASE_SECRETID') &&
    readSecretEnv('CLOUDBASE_SECRETKEY'),
  );
}

export function getCloudbaseRuntimeDiagnostics() {
  return {
    dataStore: config.dataStore,
    cloudbaseEnvId: config.cloudbaseEnvId || '',
    cloudbaseTimeoutMs: config.cloudbaseTimeoutMs,
    hasCloudbaseApiKey: Boolean(readSecretEnv('CLOUDBASE_APIKEY')),
    hasCloudbaseSecretPair: hasCloudbaseSecretPair(),
    hasTencentCloudSecretPair: hasTencentCloudSecretPair(),
    nodeEnv: readSecretEnv('NODE_ENV'),
  };
}

async function createDatabase() {
  let cloudbaseModule;

  try {
    cloudbaseModule = await import('@cloudbase/node-sdk');
  } catch (error) {
    throw new AppError(
      500,
      'CloudBase data store requires @cloudbase/node-sdk. Run npm install in backend/.',
      error instanceof Error ? error.message : String(error),
    );
  }

  const cloudbase = cloudbaseModule.default ?? cloudbaseModule;
  const env = config.cloudbaseEnvId || cloudbase.SYMBOL_CURRENT_ENV;
  const secretId =
    readSecretEnv('CLOUDBASE_SECRETID') ||
    readSecretEnv('TENCENTCLOUD_SECRETID');
  const secretKey =
    readSecretEnv('CLOUDBASE_SECRETKEY') ||
    readSecretEnv('TENCENTCLOUD_SECRETKEY');
  const initOptions = {
    env,
    timeout: config.cloudbaseTimeoutMs,
  };

  if (secretId && secretKey) {
    initOptions.secretId = secretId;
    initOptions.secretKey = secretKey;
  }

  console.log('CloudBase data store init:', getCloudbaseRuntimeDiagnostics());

  const app = cloudbase.init(initOptions);

  return app.database();
}

export async function getCloudbaseDatabase() {
  databasePromise ??= createDatabase();
  return databasePromise;
}

export async function collection(name) {
  const db = await getCloudbaseDatabase();
  return db.collection(name);
}

export async function withCloudbaseTimeout(operation, label) {
  let timer;

  const timeout = new Promise((resolve, reject) => {
    timer = setTimeout(() => {
      reject(new AppError(504, `CloudBase document database timed out: ${label}`));
    }, config.cloudbaseTimeoutMs);
  });

  try {
    return await Promise.race([operation(), timeout]);
  } finally {
    clearTimeout(timer);
  }
}
