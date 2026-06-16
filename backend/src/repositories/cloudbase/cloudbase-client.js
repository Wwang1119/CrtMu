import { config } from '../../config.js';
import { AppError } from '../../lib/app-error.js';

let databasePromise;
let appPromise;

function readSecretEnv(name) {
  const value = process.env[name];
  return typeof value === 'string' ? value.trim() : '';
}

function readSecretEnvAlias(...names) {
  for (const name of names) {
    const value = readSecretEnv(name);
    if (value) return value;
  }

  return '';
}

function hasTencentCloudSecretPair() {
  return Boolean(
    readSecretEnvAlias('TENCENTCLOUD_SECRET_ID', 'TENCENTCLOUD_SECRETID') &&
    readSecretEnvAlias('TENCENTCLOUD_SECRET_KEY', 'TENCENTCLOUD_SECRETKEY'),
  );
}

function hasCloudbaseSecretPair() {
  return Boolean(
    readSecretEnvAlias('CLOUDBASE_SECRET_ID', 'CLOUDBASE_SECRETID') &&
    readSecretEnvAlias('CLOUDBASE_SECRET_KEY', 'CLOUDBASE_SECRETKEY'),
  );
}

export function getCloudbaseRuntimeDiagnostics() {
  return {
    dataStore: config.dataStore,
    uploadStorage: config.uploadStorage,
    cloudbaseEnvId: config.cloudbaseEnvId || '',
    cloudbaseTimeoutMs: config.cloudbaseTimeoutMs,
    cloudbaseStoragePrefix: config.cloudbaseStoragePrefix,
    cloudbaseTempUrlMaxAgeSeconds: config.cloudbaseTempUrlMaxAgeSeconds,
    hasCloudbaseApiKey: Boolean(readSecretEnv('CLOUDBASE_APIKEY')),
    hasCloudbaseSecretPair: hasCloudbaseSecretPair(),
    hasTencentCloudSecretPair: hasTencentCloudSecretPair(),
    nodeEnv: readSecretEnv('NODE_ENV'),
  };
}

async function createCloudbaseApp() {
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
    readSecretEnvAlias('CLOUDBASE_SECRET_ID', 'CLOUDBASE_SECRETID') ||
    readSecretEnvAlias('TENCENTCLOUD_SECRET_ID', 'TENCENTCLOUD_SECRETID');
  const secretKey =
    readSecretEnvAlias('CLOUDBASE_SECRET_KEY', 'CLOUDBASE_SECRETKEY') ||
    readSecretEnvAlias('TENCENTCLOUD_SECRET_KEY', 'TENCENTCLOUD_SECRETKEY');
  const initOptions = {
    env,
    timeout: config.cloudbaseTimeoutMs,
  };

  if (secretId && secretKey) {
    initOptions.secretId = secretId;
    initOptions.secretKey = secretKey;
  }

  console.log('CloudBase data store init:', getCloudbaseRuntimeDiagnostics());

  return cloudbase.init(initOptions);
}

export async function getCloudbaseApp() {
  appPromise ??= createCloudbaseApp();
  return appPromise;
}

async function createDatabase() {
  const app = await getCloudbaseApp();
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
