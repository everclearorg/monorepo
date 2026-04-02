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

// The legacy checkpoint key ({prefix}_{domain}) was written by Goldsky-only code
// using txNonce semantics. Only Goldsky should inherit it; Envio (blockNumber-based)
// must start from 0 to avoid cursor-semantic mismatches.
const LEGACY_READER_TYPE = 'goldsky';

/**
 * Load per-reader checkpoint values from the database.
 * Falls back to the legacy checkpoint key (`{prefix}_{domain}`) only for the
 * Goldsky reader, since legacy checkpoints used txNonce semantics.
 * Other readers (e.g., Envio) start from 0 when no per-reader checkpoint exists.
 */
export const loadReaderCheckpoints = async (
  database: CheckpointDatabase,
  prefix: string,
  domain: string,
  readerTypes: string[],
): Promise<ReaderCheckpoints> => {
  const legacyKey = `${prefix}_${domain}`;
  const needsLegacy = readerTypes.includes(LEGACY_READER_TYPE);
  const [legacyValue, ...perReaderValues] = await Promise.all([
    needsLegacy ? database.getCheckPoint(legacyKey) : Promise.resolve(0),
    ...readerTypes.map((rt) => database.getCheckPoint(checkpointKey(prefix, rt, domain))),
  ]);

  const checkpoints: ReaderCheckpoints = {};
  for (let i = 0; i < readerTypes.length; i++) {
    if (perReaderValues[i]) {
      // Per-reader checkpoint exists, use it
      checkpoints[readerTypes[i]] = perReaderValues[i];
    } else if (readerTypes[i] === LEGACY_READER_TYPE) {
      // Fall back to legacy only for Goldsky (same cursor semantics)
      checkpoints[readerTypes[i]] = legacyValue;
    } else {
      // Other readers (e.g., Envio) start from 0 — no cross-semantic fallback
      checkpoints[readerTypes[i]] = 0;
    }
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
