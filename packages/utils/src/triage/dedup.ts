import { TriageProcessingRecord, TriagePersistenceStore } from './types';

const inMemoryStore = new Map<string, number>();
const inMemoryFinalized = new Set<string>();
let triageStore: TriagePersistenceStore = {
  hasProcessed: async (fingerprint: string) => {
    const expiresAt = inMemoryStore.get(fingerprint);
    if (!expiresAt) {
      return false;
    }
    if (Date.now() > expiresAt) {
      inMemoryStore.delete(fingerprint);
      return false;
    }
    return inMemoryFinalized.has(fingerprint);
  },
  tryReserve: async (record: TriageProcessingRecord) => {
    const expiresAt = inMemoryStore.get(record.fingerprint);
    if (expiresAt && expiresAt > Date.now()) {
      return false;
    }
    inMemoryStore.set(record.fingerprint, record.expiresAt.getTime());
    inMemoryFinalized.delete(record.fingerprint);
    return true;
  },
  finalize: async (record: TriageProcessingRecord) => {
    inMemoryStore.set(record.fingerprint, record.expiresAt.getTime());
    inMemoryFinalized.add(record.fingerprint);
  },
  pruneExpired: async () => {
    const now = Date.now();
    let count = 0;
    for (const [fingerprint, expiresAt] of inMemoryStore.entries()) {
      if (expiresAt <= now) {
        inMemoryStore.delete(fingerprint);
        inMemoryFinalized.delete(fingerprint);
        count += 1;
      }
    }
    return count;
  },
};

export const setTriagePersistenceStore = (store: TriagePersistenceStore) => {
  triageStore = store;
};

export const isProcessedFingerprint = async (fingerprint: string): Promise<boolean> => {
  return triageStore.hasProcessed ? triageStore.hasProcessed(fingerprint) : false;
};

export const tryReserveFingerprint = async (record: TriageProcessingRecord): Promise<boolean> => {
  return triageStore.tryReserve(record);
};

export const finalizeFingerprint = async (record: TriageProcessingRecord): Promise<void> => {
  await triageStore.finalize(record);
};

export const setAutoResolveOutcome = async (
  fingerprint: string,
  succeeded: boolean,
  reasonCode?: string,
): Promise<void> => {
  if (triageStore.setAutoResolveOutcome) {
    await triageStore.setAutoResolveOutcome(fingerprint, succeeded, reasonCode);
  }
};

export const pruneExpiredFingerprints = async (): Promise<number> => {
  return triageStore.pruneExpired ? triageStore.pruneExpired() : 0;
};
