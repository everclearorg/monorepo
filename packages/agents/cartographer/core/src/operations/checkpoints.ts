import { ReaderCheckpoints } from '@chimera-monorepo/adapters-subgraph';

interface CheckpointDatabase {
  getCheckPoint(key: string): Promise<number>;
  saveCheckPoint(key: string, value: number): Promise<void>;
}

/**
 * Build a checkpoint key for a specific reader type.
 * Format: `{prefix}_{readerType}_{domain}` (e.g., `hub_invoice_envio_25327`)
 */
const checkpointKey = (prefix: string, readerType: string, domain: string): string =>
  `${prefix}_${readerType}_${domain}`;

/**
 * Load per-reader checkpoint values from the database.
 * Falls back to the legacy checkpoint key (`{prefix}_{domain}`) for readers
 * that don't yet have a per-reader checkpoint saved.
 */
export const loadReaderCheckpoints = async (
  database: CheckpointDatabase,
  prefix: string,
  domain: string,
  readerTypes: string[],
): Promise<ReaderCheckpoints> => {
  const legacyKey = `${prefix}_${domain}`;
  const [legacyValue, ...perReaderValues] = await Promise.all([
    database.getCheckPoint(legacyKey),
    ...readerTypes.map((rt) => database.getCheckPoint(checkpointKey(prefix, rt, domain))),
  ]);

  const checkpoints: ReaderCheckpoints = {};
  for (let i = 0; i < readerTypes.length; i++) {
    // Use the per-reader checkpoint if it exists (non-zero), otherwise fall back to legacy
    checkpoints[readerTypes[i]] = perReaderValues[i] || legacyValue;
  }
  return checkpoints;
};

/**
 * Save per-reader checkpoint values to the database.
 * Only saves checkpoints for readers that returned results (non-zero values).
 */
export const saveReaderCheckpoints = async (
  database: CheckpointDatabase,
  prefix: string,
  domain: string,
  checkpoints: ReaderCheckpoints,
): Promise<void> => {
  const saves: Promise<void>[] = [];
  for (const [readerType, value] of Object.entries(checkpoints)) {
    if (value > 0) {
      saves.push(database.saveCheckPoint(checkpointKey(prefix, readerType, domain), value));
    }
  }
  await Promise.all(saves);
};
